#!/bin/bash

## Shared implementation for the developer file-download tools
## (download_files.sh and download_static.sh). Not meant to be run directly;
## it is sourced by those scripts.
##
## Verifies local dependencies, sources the shared S3 credential helpers, and
## defines download_backup_files() which does the actual download / extract.

if [ "$(uname -s)" = "Darwin" ]; then
  if ! hash brew 2>/dev/null ; then
    echo "Please install Homebrew:
    /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
    echo
    echo "NOTE: You will need sudoer permission."
    echo "Linux: https://linuxize.com/post/how-to-add-user-to-sudoers-in-ubuntu/"
    echo "MacOS: https://osxdaily.com/2014/02/06/add-user-sudoers-file-mac/"
    exit 1
  fi
fi

if ! hash cf 2>/dev/null ; then
  echo "Please install cf version 8:
    Linux: https://docs.cloudfoundry.org/cf-cli/install-go-cli.html
    Homebrew:
      brew tap cloudfoundry/tap
      brew install cf-cli@8"
  exit 1
elif [[ "$(cf --version)" != *"cf version 8."* ]]; then
  echo "Please install cf version 8:
  Linux: https://docs.cloudfoundry.org/cf-cli/install-go-cli.html
  Homebrew:
    brew uninstall cf-cli
    brew tap cloudfoundry/tap
    brew install cf-cli@8"
  exit 1
fi

if ! hash jq 2>/dev/null ; then
  echo "Please install jq:
    Linux: https://jqlang.github.io/jq/download/
    Homebrew:
      brew install jq"
  exit 1
fi

if ! hash aws 2>/dev/null ; then
  echo "Please install the AWS CLI:
    https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html
    Homebrew:
      brew install awscli"
  exit 1
fi

## Resolve repo paths and source the shared S3 credential helpers.
COMMON_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "${COMMON_DIR}")"
source "${COMMON_DIR}/pipeline/s3-credentials.sh"

RED='\033[0;31m'
NC='\033[0m'

## Resolve the project name (the prefix used to name all cloud.gov services,
## e.g. "digital-gov" in "digital-gov-backup-dev"). The canonical source is the
## Terraform locals file, which is also what names the real infrastructure, so
## the scripts can never disagree with what is actually deployed. Echoes the
## value, or nothing if it cannot be found.
resolve_project() {
  local locals_file="${REPO_ROOT}/terraform/infra/locals.tf"
  [[ -f "${locals_file}" ]] || return 0
  grep -E '^[[:space:]]*project[[:space:]]*=[[:space:]]*"' "${locals_file}" \
    | head -1 \
    | sed -E 's/.*project[[:space:]]*=[[:space:]]*"([^"]+)".*/\1/'
}

## Resolve the cloud.gov space from the current `cf target`, or nothing if no
## space is targeted.
resolve_space() {
  cf target 2>/dev/null | awk -F'[[:space:]]+' '/^space:/ {print $2}'
}

## Download (and optionally extract) a file backup from the backup bucket.
##
## The project is derived from the repo's Terraform config and the space from
## the current `cf target` -- there are no flags for them. To operate on a
## different space, switch to it first with `cf target -s <space>`.
##
## Arguments:
##   $1  files_type    "storage" or "static".
##   $2  default_dir   Default extraction directory for this type.
##   $3  strip_prefix  Optional. A path prefix within the archive to extract and
##                     strip on extraction. Used for "storage": the bucket stores
##                     public files under "cms/public/" (s3fs root_folder=cms,
##                     public_folder=public), but a local Drupal serves them from
##                     sites/default/files relative to public://. Passing
##                     "cms/public" extracts just that subtree and removes the
##                     prefix so files land at the correct local paths. When
##                     empty (e.g. "static"), the archive is extracted verbatim.
download_backup_files() {
  local files_type="$1"
  local default_dir="$2"
  local strip_prefix="${3:-}"

  local project space
  project="$(resolve_project)"
  space="$(resolve_space)"

  if [[ -z "${project}" ]]; then
    echo -e "${RED}Error: could not determine the project name from terraform/infra/locals.tf.${NC}"
    exit 1
  fi
  if [[ -z "${space}" ]]; then
    echo -e "${RED}Error: no space targeted. Run 'cf target -s <space>' first.${NC}"
    exit 1
  fi

  if [[ "${retrieve_date}" != "latest" && ! "${retrieve_date}" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
    echo -e "${RED}Error: -d must be 'latest' or a 'YYYY-MM-DD' date.${NC}"
    exit 1
  fi

  local backup_service="${project}-backup-${space}"

  echo "Using project '${project}', space '${space}'."
  echo "Getting backup bucket credentials..."
  ## Ensure the temp service key is removed even if the run is interrupted or
  ## aborts, so keys don't leak and exhaust the bucket's key quota.
  s3_autoclean_on_exit "${backup_service}"
  ## `|| true` so a failed credential fetch reaches the explicit check below
  ## instead of dying silently under `set -e` with no error message.
  read -r AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY bucket AWS_DEFAULT_REGION \
    < <(get_s3_credentials "${backup_service}") || true
  if [[ -z "${AWS_ACCESS_KEY_ID:-}" || "${AWS_ACCESS_KEY_ID}" == "null" ]]; then
    echo -e "${RED}Error: could not get S3 credentials for '${backup_service}'.${NC}"
    echo "Check that the service exists in this space and your cf session is valid"
    echo "(an expired session can be renewed with: cf login -a api.fr.cloud.gov --sso)."
    exit 1
  fi
  export AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_DEFAULT_REGION

  ## Resolve the object key to download.
  local s3_key
  if [[ "${retrieve_date}" == "latest" ]]; then
    s3_key="${files_type}/latest.tar.gz"
  else
    ## Dated backups are stored under <type>/YYYY/MM/DD/<timestamp>.tar.gz.
    local date_prefix="${files_type}/${retrieve_date//-//}/"
    echo "Looking for a backup under '${date_prefix}'..."
    ## When the prefix matches nothing, Contents is absent and the JMESPath
    ## query errors; `|| true` keeps that from aborting under `set -e` so the
    ## empty check below produces a clean error message.
    s3_key=$(aws s3api list-objects-v2 \
      --bucket "${bucket}" \
      --prefix "${date_prefix}" \
      --query 'sort_by(Contents, &LastModified)[-1].Key' \
      --output text --no-verify-ssl 2>/dev/null || true)

    if [[ -z "${s3_key}" || "${s3_key}" == "None" ]]; then
      delete_s3_credentials "${backup_service}"
      echo -e "${RED}Error: No '${files_type}' backup found for ${retrieve_date}.${NC}"
      exit 1
    fi
  fi

  local local_archive="${files_type}_${retrieve_date}.tar.gz"

  echo "Downloading '${s3_key}'..."
  ## Don't suppress the command's output: a failed download should surface its
  ## error rather than aborting silently under `set -e`. Only the noisy
  ## "InsecureRequestWarning" lines (from --no-verify-ssl) are filtered out.
  if ! aws s3 cp "s3://${bucket}/${s3_key}" "${local_archive}" --no-verify-ssl \
       2> >(grep -v -e InsecureRequestWarning -e 'warnings.warn' >&2); then
    delete_s3_credentials "${backup_service}"
    echo -e "${RED}Error: failed to download 's3://${bucket}/${s3_key}'.${NC}"
    exit 1
  fi

  delete_s3_credentials "${backup_service}"

  if [[ -z "${extract}" ]]; then
    ## Download-only: keep the archive and report where it is.
    echo "File saved: ${local_archive}"
  else
    [[ -z "${output_dir}" ]] && output_dir="${default_dir}"

    echo "Extracting into '${output_dir}'..."
    mkdir -p "${output_dir}"

    if [[ -n "${strip_prefix}" ]]; then
      ## Extract only the prefixed subtree (e.g. "cms/public") and strip that
      ## prefix so files land at the paths a local Drupal expects under
      ## sites/default/files (relative to public://).
      ##
      ## Find how the prefix is actually stored. Archives created with
      ## `tar -C dir .` prefix entries with "./", so the real stored path may be
      ## "./cms/public/..."; strip-components must match that exact depth.
      local stored_prefix
      stored_prefix=$(tar -tzf "${local_archive}" \
        | grep -m1 -E "(^|^\./)${strip_prefix}/" \
        | grep -oE "(\./)?${strip_prefix}/")
      if [[ -z "${stored_prefix}" ]]; then
        echo -e "${RED}Error: expected prefix '${strip_prefix}/' not found in the archive.${NC}"
        exit 1
      fi
      ## Depth = number of path segments in the stored prefix (trailing slash
      ## removed), e.g. "./cms/public" -> 3, "cms/public" -> 2.
      local depth
      depth=$(echo "${stored_prefix%/}" | tr -cd '/' | wc -c | tr -d ' ')
      depth=$((depth + 1))
      tar -xzf "${local_archive}" -C "${output_dir}" --strip-components="${depth}" "${stored_prefix%/}"
    else
      tar -xzf "${local_archive}" -C "${output_dir}"
    fi

    ## The archive was only a means to extract; remove it so multi-GB downloads
    ## don't linger in the working directory.
    rm -f "${local_archive}"
    echo "Extraction complete."
  fi
}
