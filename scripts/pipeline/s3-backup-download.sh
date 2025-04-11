#!/bin/bash

set -e

backup_bucket="${PROJECT}-backup-${CF_SPACE}"
space="${PROJECT}-${CF_SPACE}"

echo "Getting backup bucket credentials..."
 {
  cf target -s "${space}"

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
  
  DATABASE_FILE="database_restore.sql.gz"

  [ -n "${S3_FILE_PATH}" ] && DATABASE_FILE="${S3_FILE_PATH}"

  aws s3 cp "s3://${bucket}/${DATABASE_FILE}" database_restore.sql.gz  --no-verify-ssl # 2>/dev/null
  
  cf delete-service-key "${service}" "${service_key}" -f

 } &> /dev/null

echo "File downloaded: ${DATABASE_FILE}"
