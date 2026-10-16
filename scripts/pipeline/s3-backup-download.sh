#!/bin/bash

set -e

## The space whose backup bucket to download from. Defaults to the space being
## restored; set it to restore another space's backup (e.g. prod into staging).
BACKUP_SPACE="${BACKUP_SPACE:-${CF_SPACE}}"

backup_bucket="${PROJECT}-backup-${BACKUP_SPACE}"

echo "Getting backup bucket credentials..."
 {
  ## Service keys are created in the targeted space.
  cf target -s "${BACKUP_SPACE}"

  service="${backup_bucket}"
  service_key="${service}-pipeline-download-${CF_SPACE}-key"
  cf delete-service-key "${service}" "${service_key}" -f
  cf create-service-key "${service}" "${service_key}"
  sleep 2
  s3_credentials=$(cf service-key "${service}" "${service_key}" | tail -n +2)

  AWS_ACCESS_KEY_ID=$(echo "${s3_credentials}" | jq -r '.credentials.access_key_id')
  export AWS_ACCESS_KEY_ID

  bucket=$(echo "${s3_credentials}" | jq -r '.credentials.bucket')
  export bucket

  AWS_BUCKET="${bucket}"
  export AWS_BUCKET

  AWS_DEFAULT_REGION=$(echo "${s3_credentials}" | jq -r '.credentials.region')
  export AWS_DEFAULT_REGION

  AWS_SECRET_ACCESS_KEY=$(echo "${s3_credentials}" | jq -r '.credentials.secret_access_key')
  export AWS_SECRET_ACCESS_KEY

 }  &> /dev/null

echo "Downloading backup..."
 {

  rm -f "*.sql"

  ## The copy database-backup.sh refreshes on every run.
  DATABASE_FILE="latest.sql.gz"

  [ -n "${S3_FILE_PATH}" ] && DATABASE_FILE="${S3_FILE_PATH}"

  aws s3 cp "s3://${bucket}/${DATABASE_FILE}" database_restore.sql.gz  --no-verify-ssl # 2>/dev/null

  cf delete-service-key "${service}" "${service_key}" -f

  cf target -s "${CF_SPACE}"

 } &> /dev/null

echo "File downloaded: ${DATABASE_FILE} from ${BACKUP_SPACE}"
