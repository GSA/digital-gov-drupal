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
## By default this is non-destructive and reuses whatever is already local:
##   - Database: if the local Lando DB already has content it is left untouched;
##     otherwise a previously downloaded dump is reused if present; otherwise a
##     fresh backup is downloaded and imported.
##   - Public files: if web/sites/default/files already has content it is reused;
##     otherwise the backup is downloaded and extracted.
## Use the --force-* flags to override detection and pull fresh copies.
##
## Usage:
##   ./scripts/refresh-local.sh [options]
##
##   --force-db     Always download a fresh database backup and re-import,
##                  replacing the current local database.
##   --force-files  Always download and extract a fresh copy of the public
##                  files (~2GB), even if local files already exist.
##   -d <date>      Backup to use: 'latest' (default) or 'YYYY-MM-DD'.
##   -h             Show this help.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "${SCRIPT_DIR}")"

## Reuse dependency checks, project/space resolution and the S3 credential
## helpers (get_s3_credentials / s3_autoclean_on_exit / resolve_project / ...).
source "${SCRIPT_DIR}/download_files_common.sh"

## download_files_common.sh defines RED/NC; add colors used for reuse notices.
GREEN='\033[0;32m'
YELLOW='\033[0;33m'

help(){
  echo "Usage: $0 [options]" >&2
  echo
  echo "Refresh the local Lando site from the currently targeted Cloud.gov space."
  echo "Imports the database, loads public files, re-applies local config and"
  echo "rebuilds caches so image styles and uploads render locally."
  echo
  echo "By default this reuses whatever is already local (a populated local DB, a"
  echo "cached database dump, or existing public files) and only downloads what is"
  echo "missing. Use the --force-* flags to pull fresh copies."
  echo
  echo "   --force-db     Always download a fresh database backup and re-import,"
  echo "                  replacing the current local database."
  echo "   --force-files  Always download and extract fresh public files (~2GB),"
  echo "                  even if local files already exist."
  echo "   -d <date>      Backup to use: 'latest' (default) or 'YYYY-MM-DD'."
  echo "   -h             Show this help."
}

retrieve_date="latest"
force_db=""
force_files=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --force-db)    force_db="true" ; shift ;;
    --force-files) force_files="true" ; shift ;;
    -d)            retrieve_date="$2" ; shift 2 ;;
    -h|--help)     help ; exit 0 ;;
    *)             help ; echo -e "\n${RED}Error: unknown option '$1'.${NC}" ; exit 1 ;;
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

## `cf target` reads cached state and succeeds even after the auth token has
## expired, which would otherwise surface later as a confusing silent failure
## while fetching S3 credentials. Verify the session is actually usable now.
if ! cf oauth-token >/dev/null 2>&1; then
  echo -e "${RED}Error: your Cloud.gov session has expired. Log in again first:${NC}"
  echo "  cf login -a api.fr.cloud.gov --sso"
  exit 1
fi

echo "Refreshing local site from project '${project}', space '${space}'."

## Cached artifacts left behind by previous runs so they can be reused without
## re-downloading. The .sql.gz is kept as the database cache; extracted public
## files live in web/sites/default/files.
db_archive="${REPO_ROOT}/digitalgov.sql.gz"
files_dir="${REPO_ROOT}/web/sites/default/files"

## Return success if the local Lando database already holds a working Drupal
## site, so we can avoid clobbering it by default. Uses Drupal's bootstrap
## status rather than raw SQL: it only reports "Successful" when Drupal is
## actually installed and the database is usable, so an empty or broken
## database correctly falls through to a (re)import.
local_db_has_content() {
  [[ "$(lando drush status --field=bootstrap 2>/dev/null | tr -d '[:space:]')" == "Successful" ]]
}

## Download the requested database backup to ${db_archive}, replacing any cache.
download_db_backup() {
  local backup_service="${project}-backup-${space}"

  echo "==> Downloading database backup..."
  s3_autoclean_on_exit "${backup_service}"
  ## `|| true` so a failed credential fetch reaches the explicit check below
  ## instead of dying silently under `set -e` with no error message.
  read -r AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY bucket AWS_DEFAULT_REGION \
    < <(get_s3_credentials "${backup_service}") || true
  if [[ -z "${AWS_ACCESS_KEY_ID:-}" || "${AWS_ACCESS_KEY_ID}" == "null" ]]; then
    echo -e "${RED}Error: could not get S3 credentials for '${backup_service}'.${NC}"
    echo "Check that the service exists in this space and your cf session is valid."
    exit 1
  fi
  export AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_DEFAULT_REGION

  ## The database backup is stored at the bucket root: latest.sql.gz, with dated
  ## copies under YYYY/MM/DD/<timestamp>.sql.gz.
  local db_key
  if [[ "${retrieve_date}" == "latest" ]]; then
    db_key="latest.sql.gz"
  else
    local db_prefix="${retrieve_date//-//}/"
    echo "Looking for a database backup under '${db_prefix}'..."
    db_key=$(aws s3api list-objects-v2 --bucket "${bucket}" --prefix "${db_prefix}" \
      --query 'sort_by(Contents[?ends_with(Key, `.sql.gz`)], &LastModified)[-1].Key' \
      --output text --no-verify-ssl 2>/dev/null || true)
    if [[ -z "${db_key}" || "${db_key}" == "None" ]]; then
      echo -e "${RED}Error: no database backup found for ${retrieve_date}.${NC}"
      exit 1
    fi
  fi

  rm -f "${db_archive}"
  if ! aws s3 cp "s3://${bucket}/${db_key}" "${db_archive}" --no-verify-ssl \
       2> >(grep -v -e InsecureRequestWarning -e 'warnings.warn' >&2); then
    echo -e "${RED}Error: failed to download 's3://${bucket}/${db_key}'.${NC}"
    exit 1
  fi
  ## Backup creds no longer needed; drop the key early (trap will also cover it).
  delete_s3_credentials "${backup_service}"
}

## Import the cached ${db_archive} into the local Lando database.
import_db_archive() {
  local db_sql="${REPO_ROOT}/digitalgov.sql"

  echo "==> Importing database into local Lando..."
  ## Decompress to a working copy but keep the .gz so it stays available as a
  ## cache for future reruns.
  gunzip -c "${db_archive}" > "${db_sql}"
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
}

## ---------------------------------------------------------------------------
## 1. Database
## ---------------------------------------------------------------------------
## Tracks whether upstream data was (re)loaded this run, so the s3fs cleanup
## below only runs when it is actually needed.
db_loaded=""

echo ""
if [[ -n "${force_db}" ]]; then
  echo -e "${YELLOW}--force-db: replacing the local database with a fresh backup.${NC}"
  download_db_backup
  import_db_archive
  db_loaded="true"
elif local_db_has_content; then
  echo -e "${GREEN}Local database already has content; leaving it untouched.${NC}"
  echo "    Use --force-db to replace it with a fresh backup."
elif [[ -f "${db_archive}" ]]; then
  echo -e "${GREEN}Using cached database dump ($(basename "${db_archive}")).${NC}"
  echo "    Use --force-db to download a fresh backup instead."
  import_db_archive
  db_loaded="true"
else
  echo "No local database detected; downloading a fresh backup."
  download_db_backup
  import_db_archive
  db_loaded="true"
fi

## ---------------------------------------------------------------------------
## 2. Public files (originals + image-style derivatives)
## ---------------------------------------------------------------------------
echo ""
if [[ -n "${force_files}" ]]; then
  echo -e "${YELLOW}--force-files: downloading a fresh copy of the public files.${NC}"
  "${SCRIPT_DIR}/download_files.sh" -x -d "${retrieve_date}"
elif [[ -d "${files_dir}" ]] && find "${files_dir}" -mindepth 1 -type f -print -quit 2>/dev/null | grep -q .; then
  echo -e "${GREEN}Local public files already present; using them.${NC}"
  echo "    Use --force-files to download a fresh copy (~2GB)."
else
  echo "No local public files detected; downloading and extracting them."
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
if [[ -n "${db_loaded}" ]]; then
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
