#!/bin/bash

## Developer tool to download a backup of the generated static site (the
## "static" S3 bucket) and optionally extract it locally for inspection or
## serving.
##
## Operates on the currently targeted Cloud.gov space. Log in and select the
## space first: `cf login -a api.fr.cloud.gov --sso` then `cf target -s <space>`.

set -e

## Source shared dependency checks, credential helpers and download logic.
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/download_files_common.sh"

help(){
  echo "Usage: $0 [options]" >&2
  echo
  echo "Download a backup of the generated static site from the currently"
  echo "targeted Cloud.gov space (see 'cf target')."
  echo
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

while getopts 'd:o:xh' flag; do
  case ${flag} in
    d) retrieve_date=${OPTARG} ;;
    o) output_dir=${OPTARG} ;;
    x) extract="true" ;;
    h) help && exit 0 ;;
    *) help && exit 1 ;;
  esac
done

download_backup_files "static" "${REPO_ROOT}/static-download"
