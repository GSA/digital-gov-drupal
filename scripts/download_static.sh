#!/bin/bash

## Developer tool to download a backup of the generated static site (the
## "static" S3 bucket) and optionally extract it locally for inspection or
## serving.
##
## Requires being logged into Cloud.gov (`cf login -a api.fr.cloud.gov --sso`)
## with access to the target space.

set -e

## Source shared dependency checks, credential helpers and download logic.
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/download_files_common.sh"

help(){
  echo "Usage: $0 [options]" >&2
  echo
  echo "Download a backup of the generated static site."
  echo
  echo "   -p           The project name (e.g. the prefix of cloud.gov service names)."
  echo "   -s           Name of the space the backup bucket is in (e.g. dev, staging, prod)."
  echo "   -d           Backup to retrieve. Acceptable values are 'latest' (default)"
  echo "                or a date in 'YYYY-MM-DD' format."
  echo "   -x           Extract the archive after download."
  echo "   -o           Output directory for extraction."
  echo "                Defaults to ./static-download."
  echo "   -h           Show this help."
}

retrieve_date="latest"
extract=""
output_dir=""

while getopts 'p:s:d:o:xh' flag; do
  case ${flag} in
    p) project=${OPTARG} ;;
    s) space=${OPTARG} ;;
    d) retrieve_date=${OPTARG} ;;
    o) output_dir=${OPTARG} ;;
    x) extract="true" ;;
    h) help && exit 0 ;;
    *) help && exit 1 ;;
  esac
done

[[ -z "${project}" ]] && help && echo -e "\n${RED}Error: Missing -p flag.${NC}" && exit 1
[[ -z "${space}" ]] && help && echo -e "\n${RED}Error: Missing -s flag.${NC}" && exit 1

download_backup_files "static" "${REPO_ROOT}/static-download"
