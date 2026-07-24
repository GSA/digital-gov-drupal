#!/bin/bash

## Backs up the contents of an S3 bucket (Drupal public files or the
## statically generated site) into the project's backup S3 bucket.
##
## Usage:
##   FILES_BACKUP_TYPE=<storage|static> source ./scripts/pipeline/files-backup.sh
##
## Required environment variables:
##   PROJECT                The project name (e.g. used to build service names).
##   CF_SPACE               The Cloud Foundry space (e.g. prod, staging, dev).
##   FILES_BACKUP_TYPE      Which source bucket to back up: "storage" or "static".
##   TIMESTAMP              The timestamp used to name the backup archive.

set -e

## Validate the backup type argument.
if [[ "${FILES_BACKUP_TYPE}" != "storage" && "${FILES_BACKUP_TYPE}" != "static" ]]; then
  echo "Error: FILES_BACKUP_TYPE must be set to 'storage' or 'static'."
  exit 1
fi

if [[ -z "${PROJECT}" || -z "${CF_SPACE}" || -z "${TIMESTAMP}" ]]; then
  echo "Error: PROJECT, CF_SPACE and TIMESTAMP must all be set."
  exit 1
fi

date

## Working directory for the download.
WORK_DIR="files_backup_${FILES_BACKUP_TYPE}"
ARCHIVE_NAME="${TIMESTAMP}.tar.gz"

## Shared helpers: get_s3_credentials / delete_s3_credentials.
source "$(dirname "${BASH_SOURCE[0]}")/s3-credentials.sh"

SOURCE_SERVICE="${PROJECT}-${FILES_BACKUP_TYPE}-${CF_SPACE}"
BACKUP_SERVICE="${PROJECT}-backup-${CF_SPACE}"

echo "Getting '${FILES_BACKUP_TYPE}' bucket credentials..."
read -r SRC_ACCESS_KEY SRC_SECRET_KEY SRC_BUCKET SRC_REGION < <(get_s3_credentials "${SOURCE_SERVICE}")

echo "Downloading '${FILES_BACKUP_TYPE}' files from bucket..."
{
  rm -rf "${WORK_DIR}"
  mkdir -p "${WORK_DIR}"

  AWS_ACCESS_KEY_ID="${SRC_ACCESS_KEY}" \
  AWS_SECRET_ACCESS_KEY="${SRC_SECRET_KEY}" \
  AWS_DEFAULT_REGION="${SRC_REGION}" \
    aws s3 sync "s3://${SRC_BUCKET}" "${WORK_DIR}" --no-verify-ssl 2>/dev/null
} >/dev/null 2>&1

## The source credentials are no longer needed.
delete_s3_credentials "${SOURCE_SERVICE}"

date

echo "Compressing '${FILES_BACKUP_TYPE}' files..."
{
  tar -czf "${ARCHIVE_NAME}" -C "${WORK_DIR}" .
} >/dev/null 2>&1

echo "Getting backup bucket credentials..."
read -r BACKUP_ACCESS_KEY BACKUP_SECRET_KEY BACKUP_BUCKET BACKUP_REGION < <(get_s3_credentials "${BACKUP_SERVICE}")

echo "Saving to backup bucket..."
{
  export AWS_ACCESS_KEY_ID="${BACKUP_ACCESS_KEY}"
  export AWS_SECRET_ACCESS_KEY="${BACKUP_SECRET_KEY}"
  export AWS_DEFAULT_REGION="${BACKUP_REGION}"

  ## Dated, point-in-time copy.
  aws s3 cp "${ARCHIVE_NAME}" \
    "s3://${BACKUP_BUCKET}/${FILES_BACKUP_TYPE}/$(date +%Y)/$(date +%m)/$(date +%d)/" \
    --no-verify-ssl 2>/dev/null

  ## Convenience "latest" copy used by the restore process.
  aws s3 cp "${ARCHIVE_NAME}" \
    "s3://${BACKUP_BUCKET}/${FILES_BACKUP_TYPE}/latest.tar.gz" \
    --no-verify-ssl 2>/dev/null
} >/dev/null 2>&1

echo "Cleaning up..."
delete_s3_credentials "${BACKUP_SERVICE}"
rm -rf "${WORK_DIR}" "${ARCHIVE_NAME}"

echo "Backup of '${FILES_BACKUP_TYPE}' files complete."
date
