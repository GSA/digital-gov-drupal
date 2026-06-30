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

## Download (and optionally extract) a file backup from the backup bucket.
##
## Arguments:
##   $1  files_type    "storage" or "static".
##   $2  default_dir   Default extraction directory for this type.
##
## Reads the following variables set by the calling script:
##   project, space, retrieve_date, extract, output_dir
download_backup_files() {
  local files_type="$1"
  local default_dir="$2"

  if [[ "${retrieve_date}" != "latest" && ! "${retrieve_date}" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
    echo -e "${RED}Error: -d must be 'latest' or a 'YYYY-MM-DD' date.${NC}"
    exit 1
  fi

  local backup_service="${project}-backup-${space}"

  echo "Getting backup bucket credentials..."
  if ! cf target -s "${space}" >/dev/null 2>&1; then
    echo -e "${RED}Error: could not target space '${space}'. Are you logged in (cf login) with access to it?${NC}"
    exit 1
  fi
  read -r AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY bucket AWS_DEFAULT_REGION < <(get_s3_credentials "${backup_service}")
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
  {
    aws s3 cp "s3://${bucket}/${s3_key}" "${local_archive}" --no-verify-ssl 2>/dev/null
  } >/dev/null 2>&1

  delete_s3_credentials "${backup_service}"

  echo "File saved: ${local_archive}"

  if [[ -n "${extract}" ]]; then
    [[ -z "${output_dir}" ]] && output_dir="${default_dir}"

    echo "Extracting into '${output_dir}'..."
    mkdir -p "${output_dir}"
    tar -xzf "${local_archive}" -C "${output_dir}"
    echo "Extraction complete."
  fi
}
