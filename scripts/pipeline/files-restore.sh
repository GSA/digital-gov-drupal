#!/bin/bash

## Restores the contents of a previously backed up S3 archive (Drupal public
## files or the statically generated site) from the project's backup S3 bucket
## back into the live bucket.
##
## Usage:
##   FILES_BACKUP_TYPE=<storage|static> source ./scripts/pipeline/files-restore.sh
##
## Required environment variables:
##   PROJECT                The project name (e.g. used to build service names).
##   CF_SPACE               The Cloud Foundry space (e.g. prod, staging, dev).
##   FILES_BACKUP_TYPE      Which bucket to restore: "storage" or "static".
##
## Optional environment variables:
##   S3_FILE_PATH           Path within the backup bucket to a specific archive.
##                          Defaults to "<type>/latest.tar.gz".

set -e

## Validate the backup type argument.
if [[ "${FILES_BACKUP_TYPE}" != "storage" && "${FILES_BACKUP_TYPE}" != "static" ]]; then
  echo "Error: FILES_BACKUP_TYPE must be set to 'storage' or 'static'."
  exit 1
fi

if [[ -z "${PROJECT}" || -z "${CF_SPACE}" ]]; then
  echo "Error: PROJECT and CF_SPACE must both be set."
  exit 1
fi

date

## Working directory for the extracted archive.
WORK_DIR="files_restore_${FILES_BACKUP_TYPE}"
ARCHIVE_NAME="files_restore_${FILES_BACKUP_TYPE}.tar.gz"

## The archive to restore from, defaulting to the convenience "latest" copy.
BACKUP_FILE="${FILES_BACKUP_TYPE}/latest.tar.gz"
[ -n "${S3_FILE_PATH}" ] && BACKUP_FILE="${S3_FILE_PATH}"

## Shared helpers: get_s3_credentials / delete_s3_credentials.
source "$(dirname "${BASH_SOURCE[0]}")/s3-credentials.sh"

TARGET_SERVICE="${PROJECT}-${FILES_BACKUP_TYPE}-${CF_SPACE}"
BACKUP_SERVICE="${PROJECT}-backup-${CF_SPACE}"

echo "Getting backup bucket credentials..."
read -r BACKUP_ACCESS_KEY BACKUP_SECRET_KEY BACKUP_BUCKET BACKUP_REGION < <(get_s3_credentials "${BACKUP_SERVICE}")

echo "Downloading '${BACKUP_FILE}' from backup bucket..."
{
  rm -rf "${WORK_DIR}" "${ARCHIVE_NAME}"

  AWS_ACCESS_KEY_ID="${BACKUP_ACCESS_KEY}" \
  AWS_SECRET_ACCESS_KEY="${BACKUP_SECRET_KEY}" \
  AWS_DEFAULT_REGION="${BACKUP_REGION}" \
    aws s3 cp "s3://${BACKUP_BUCKET}/${BACKUP_FILE}" "${ARCHIVE_NAME}" --no-verify-ssl 2>/dev/null
} >/dev/null 2>&1

## The backup credentials are no longer needed.
delete_s3_credentials "${BACKUP_SERVICE}"

echo "Extracting archive..."
{
  mkdir -p "${WORK_DIR}"
  tar -xzf "${ARCHIVE_NAME}" -C "${WORK_DIR}"
} >/dev/null 2>&1

date

echo "Getting '${FILES_BACKUP_TYPE}' bucket credentials..."
read -r TARGET_ACCESS_KEY TARGET_SECRET_KEY TARGET_BUCKET TARGET_REGION < <(get_s3_credentials "${TARGET_SERVICE}")

echo "Restoring '${FILES_BACKUP_TYPE}' files to bucket..."
{
  AWS_ACCESS_KEY_ID="${TARGET_ACCESS_KEY}" \
  AWS_SECRET_ACCESS_KEY="${TARGET_SECRET_KEY}" \
  AWS_DEFAULT_REGION="${TARGET_REGION}" \
    aws s3 sync "${WORK_DIR}" "s3://${TARGET_BUCKET}" --delete --no-verify-ssl 2>/dev/null
} >/dev/null 2>&1

echo "Cleaning up..."
delete_s3_credentials "${TARGET_SERVICE}"
rm -rf "${WORK_DIR}" "${ARCHIVE_NAME}"

echo "Restore of '${FILES_BACKUP_TYPE}' files complete."
date
