#!/bin/bash

## Developer tool to download a backup of the Drupal public files (the "storage"
## S3 bucket, typically sites/default/files) and optionally extract it into the
## local environment so a local site can run with real files.
##
## Operates on the currently targeted Cloud.gov space. Log in and select the
## space first: `cf login -a api.fr.cloud.gov --sso` then `cf target -s <space>`.

set -e

## Source shared dependency checks, credential helpers and download logic.
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/download_files_common.sh"

help(){
  echo "Usage: $0 [options]" >&2
  echo
  echo "Download a backup of the Drupal public files (uploads) from the"
  echo "currently targeted Cloud.gov space (see 'cf target')."
  echo
  echo "   -d           Backup to retrieve. Acceptable values are 'latest' (default)"
  echo "                or a date in 'YYYY-MM-DD' format."
  echo "   -x           Extract the archive into the local Drupal files dir."
  echo "                The 'cms/public/' prefix is stripped so files land at the"
  echo "                paths a local site expects. Omit -x to just keep the .tar.gz."
  echo "   -o           Output directory for extraction."
  echo "                Defaults to web/sites/default/files."
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

download_backup_files "storage" "${REPO_ROOT}/web/sites/default/files" "cms/public"
