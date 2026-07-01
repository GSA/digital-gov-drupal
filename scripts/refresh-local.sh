#!/bin/bash

## Refresh the local Lando site from a Cloud.gov backup: import the database,
## load the public files (originals + image-style derivatives), re-apply local
## configuration, and rebuild caches. This produces a fully "image-ready" local
## site in one step.
##
## Operates on the currently targeted Cloud.gov space (see `cf target`). Log in
## and select the space first:
##   cf login -a api.fr.cloud.gov --sso
##   cf target -s <space>
##
## Usage:
##   ./scripts/refresh-local.sh [options]
##
##   --no-db       Skip the database import.
##   --no-files    Skip the public files download/extract (~2GB).
##   -d <date>     Backup to use: 'latest' (default) or 'YYYY-MM-DD'.
##   -h            Show this help.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "${SCRIPT_DIR}")"

## Reuse dependency checks, project/space resolution and the S3 credential
## helpers (get_s3_credentials / s3_autoclean_on_exit / resolve_project / ...).
source "${SCRIPT_DIR}/download_files_common.sh"

help(){
  echo "Usage: $0 [options]" >&2
  echo
  echo "Refresh the local Lando site from the currently targeted Cloud.gov space."
  echo "Imports the database, loads public files, re-applies local config and"
  echo "rebuilds caches so image styles and uploads render locally."
  echo
  echo "   --no-db      Skip the database import."
  echo "   --no-files   Skip the public files download/extract (~2GB)."
  echo "   -d <date>    Backup to use: 'latest' (default) or 'YYYY-MM-DD'."
  echo "   -h           Show this help."
}

retrieve_date="latest"
do_db="true"
do_files="true"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --no-db)    do_db="" ; shift ;;
    --no-files) do_files="" ; shift ;;
    -d)         retrieve_date="$2" ; shift 2 ;;
    -h|--help)  help ; exit 0 ;;
    *)          help ; echo -e "\n${RED}Error: unknown option '$1'.${NC}" ; exit 1 ;;
  esac
done

if [[ "${retrieve_date}" != "latest" && ! "${retrieve_date}" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
  echo -e "${RED}Error: -d must be 'latest' or a 'YYYY-MM-DD' date.${NC}"
  exit 1
fi

## Lando is required for the import/config/cache steps.
if ! hash lando 2>/dev/null ; then
  echo -e "${RED}Error: 'lando' not found. This tool refreshes a local Lando site.${NC}"
  exit 1
fi

project="$(resolve_project)"
space="$(resolve_space)"
[[ -z "${project}" ]] && echo -e "${RED}Error: could not determine the project name from terraform/infra/locals.tf.${NC}" && exit 1
[[ -z "${space}" ]] && echo -e "${RED}Error: no space targeted. Run 'cf target -s <space>' first.${NC}" && exit 1

echo "Refreshing local site from project '${project}', space '${space}'."

## ---------------------------------------------------------------------------
## 1. Database
## ---------------------------------------------------------------------------
if [[ -n "${do_db}" ]]; then
  backup_service="${project}-backup-${space}"

  echo ""
  echo "==> Downloading database backup..."
  s3_autoclean_on_exit "${backup_service}"
  read -r AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY bucket AWS_DEFAULT_REGION < <(get_s3_credentials "${backup_service}")
  export AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_DEFAULT_REGION

  ## The database backup is stored at the bucket root: latest.sql.gz, with dated
  ## copies under YYYY/MM/DD/<timestamp>.sql.gz.
  if [[ "${retrieve_date}" == "latest" ]]; then
    db_key="latest.sql.gz"
  else
    db_prefix="${retrieve_date//-//}/"
    echo "Looking for a database backup under '${db_prefix}'..."
    db_key=$(aws s3api list-objects-v2 --bucket "${bucket}" --prefix "${db_prefix}" \
      --query 'sort_by(Contents[?ends_with(Key, `.sql.gz`)], &LastModified)[-1].Key' \
      --output text --no-verify-ssl 2>/dev/null || true)
    if [[ -z "${db_key}" || "${db_key}" == "None" ]]; then
      echo -e "${RED}Error: no database backup found for ${retrieve_date}.${NC}"
      exit 1
    fi
  fi

  db_archive="${REPO_ROOT}/refresh_local_db.sql.gz"
  db_sql="${REPO_ROOT}/refresh_local_db.sql"
  rm -f "${db_archive}" "${db_sql}"

  if ! aws s3 cp "s3://${bucket}/${db_key}" "${db_archive}" --no-verify-ssl \
       2> >(grep -v -e InsecureRequestWarning -e 'warnings.warn' >&2); then
    echo -e "${RED}Error: failed to download 's3://${bucket}/${db_key}'.${NC}"
    exit 1
  fi
  ## Backup creds no longer needed; drop the key early (trap will also cover it).
  delete_s3_credentials "${backup_service}"

  echo "==> Importing database into local Lando..."
  gunzip -f "${db_archive}"
  ## Cloud.gov runs MySQL 8, which emits the utf8mb4_0900_* collations and the
  ## mysql_native_password plugin; local Lando runs MariaDB, which rejects them.
  ## Rewrite those to MariaDB-compatible equivalents before importing.
  sed -i '' \
    -e 's/utf8mb4_0900_ai_ci/utf8mb4_general_ci/g' \
    -e 's/COLLATE=utf8mb4_0900_ai_ci//g' \
    "${db_sql}"
  ## lando db-import resolves the path inside the container (relative to the
  ## project root mounted at /app), so pass a project-relative filename.
  ( cd "${REPO_ROOT}" && lando db-import "$(basename "${db_sql}")" )
  rm -f "${db_sql}"
fi

## ---------------------------------------------------------------------------
## 2. Public files (originals + image-style derivatives)
## ---------------------------------------------------------------------------
if [[ -n "${do_files}" ]]; then
  echo ""
  echo "==> Downloading and extracting public files..."
  "${SCRIPT_DIR}/download_files.sh" -x -d "${retrieve_date}"
fi

## ---------------------------------------------------------------------------
## 3. Make files serve from the local filesystem + rebuild caches
## ---------------------------------------------------------------------------
## An upstream database has the s3fs module enabled, which makes Drupal look for
## public files in S3 instead of on disk -- so locally, images (including image
## style derivatives) won't render. Uninstalling s3fs is the one config change a
## local site needs after loading upstream data. This is deliberately targeted:
## it does NOT run a full `drush cim`, which can fail on unrelated config-vs-data
## conflicts when your branch's config differs from the loaded database.
if [[ -n "${do_db}" ]]; then
  echo ""
  echo "==> Ensuring files serve from the local filesystem (uninstalling s3fs)..."
  if lando drush pm:list --status=enabled --field=name 2>/dev/null | grep -qx 's3fs'; then
    lando drush pmu s3fs -y
  else
    echo "s3fs is already uninstalled locally."
  fi
fi

echo ""
echo "==> Rebuilding caches..."
lando drush cr

echo ""
echo "Local site refreshed. Opening a login link..."
lando drush uli
