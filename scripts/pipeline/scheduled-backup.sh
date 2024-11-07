#!/bin/bash

backup_space=$1

export BACKUP_ENV=${CIRCLE_BRANCH}

export backup_folder=$(date "+%Y/%m/%d")
export now=$(date +"%H.%M.%S")
export today=$(date +%F)

backup_media="cms/public/media"

rm -rf scheduled_backup/

mkdir -p scheduled_backup
cd scheduled_backup

date

echo "Downloading media files..."
{
  cf target -s "${cf_space}"

  service="${project}-storage-${BACKUP_ENV}"
  service_key="${service}-key"
  cf delete-service-key "${service}" "${service_key}" -f
  cf create-service-key "${service}" "${service_key}"
  sleep 2
  s3_credentials=$(cf service-key "${service}" "${service_key}" | tail -n +2)

  export AWS_ACCESS_KEY_ID=$(echo "${s3_credentials}" | jq -r '.credentials.access_key_id')
  export bucket=$(echo "${s3_credentials}" | jq -r '.credentials.bucket')
  export AWS_DEFAULT_REGION=$(echo "${s3_credentials}" | jq -r '.credentials.region')
  export AWS_SECRET_ACCESS_KEY=$(echo "${s3_credentials}" | jq -r '.credentials.secret_access_key')

  rm -rf ${BACKUP_ENV}

  aws s3 sync --delete --no-verify-ssl s3://${bucket}/${backup_media} ${backup_media}/ 2>/dev/null
  tar czvf media_${now}.tar.gz ${backup_media}


  cf delete-service-key "${service}" "${service_key}" -f
} >/dev/null 2>&1

date

echo "Downloading static files..."
{
  cf target -s "${cf_space}"

  service="${project}-static-${BACKUP_ENV}"
  service_key="${service}-key"
  cf delete-service-key "${service}" "${service_key}" -f
  cf create-service-key "${service}" "${service_key}"
  sleep 2
  s3_credentials=$(cf service-key "${service}" "${service_key}" | tail -n +2)

  export AWS_ACCESS_KEY_ID=$(echo "${s3_credentials}" | jq -r '.credentials.access_key_id')
  export bucket=$(echo "${s3_credentials}" | jq -r '.credentials.bucket')
  export AWS_DEFAULT_REGION=$(echo "${s3_credentials}" | jq -r '.credentials.region')
  export AWS_SECRET_ACCESS_KEY=$(echo "${s3_credentials}" | jq -r '.credentials.secret_access_key')

  rm -rf ${BACKUP_ENV}

  aws s3 sync --no-verify-ssl s3://${bucket}/ static_files/ 2>/dev/null
  tar czvf static_${now}.tar.gz static_files/


  cf delete-service-key "${service}" "${service_key}" -f
} >/dev/null 2>&1

date

echo "Downloading terraform state..."
{
  cf target -s "${backup_space}"

  service="${project}-terraform-backend"
  service_key="${service}-key"
  cf delete-service-key "${service}" "${service_key}" -f
  cf create-service-key "${service}" "${service_key}"

  sleep 2
  s3_credentials=$(cf service-key "${service}" "${service_key}" | tail -n +2)

  export AWS_ACCESS_KEY_ID=$(echo "${s3_credentials}" | jq -r '.credentials.access_key_id')
  export bucket=$(echo "${s3_credentials}" | jq -r '.credentials.bucket')
  export AWS_DEFAULT_REGION=$(echo "${s3_credentials}" | jq -r '.credentials.region')
  export AWS_SECRET_ACCESS_KEY=$(echo "${s3_credentials}" | jq -r '.credentials.secret_access_key')

  rm -rf "env:"
  aws s3 cp --recursive  --no-verify-ssl s3://${bucket}/ . 2>/dev/null

  tar czf terraform_state_${now}.tar.gz "env:"

  cf delete-service-key "${service}" "${service_key}" -f
} >/dev/null 2>&1

date

echo "Saving to backup bucket..."
{
  cf target -s "${backup_space}" >/dev/null 2>&1

  export service="${project}-backup"
  export service_key="${service}-key"
  cf delete-service-key "${service}" "${service_key}" -f >/dev/null 2>&1
  cf create-service-key "${service}" "${service_key}" >/dev/null 2>&1
  sleep 2

  export s3_credentials=$(cf service-key "${service}" "${service_key}" | tail -n +2)

  export AWS_ACCESS_KEY_ID=$(echo "${s3_credentials}" | jq -r '.credentials.access_key_id')
  export bucket=$(echo "${s3_credentials}" | jq -r '.credentials.bucket')
  export AWS_DEFAULT_REGION=$(echo "${s3_credentials}" | jq -r '.credentials.region')
  export AWS_SECRET_ACCESS_KEY=$(echo "${s3_credentials}" | jq -r '.credentials.secret_access_key')

  rm -f backup_${now}.sql
  cp ../backup_${BACKUP_ENV}.sql backup_${now}.sql
  gzip backup_${now}.sql

  aws s3 cp ./ s3://${bucket}/${BACKUP_ENV}/${backup_folder} --exclude "*" --include "*.sql.gz" --include "*.tar.gz" --recursive --no-verify-ssl >/dev/null 2>&1

  tar czf latest.tar.gz *.gz

  # delete latest and backups older than 15 days in the env's top level directory
  aws s3 rm s3://${bucket}/${BACKUP_ENV}/latest.tar.gz --no-verify-ssl >/dev/null 2>&1
  aws s3 ls s3://${bucket}/${BACKUP_ENV}/ | while read -r line; do
    create_date=$(echo $line | awk {'print $1" "$2'})
    create_date=$(date --date "$create_date" +%s 2>/dev/null)
    older_than=$(date --date "15 days ago" +%s)
    if [[ $create_date -le $older_than ]]; then
      filename=$(echo $line | awk {'print $4'})
      if [[ $filename != "" ]]; then
        aws s3 rm s3://${bucket}/${BACKUP_ENV}/$filename --no-verify-ssl >/dev/null 2>&1 && echo "Successfully deleted $filename from S3!" || echo "Failed to delete $filename from S3!"
      fi
    fi
    done;

  aws s3 cp ./latest.tar.gz s3://${bucket}/${BACKUP_ENV}/  --no-verify-ssl >/dev/null 2>&1 && echo "Successfully copied latest.tar.gz to S3!" || echo "Failed to copy latest.tar.gz to S3!"
  aws s3 cp ./latest.tar.gz s3://${bucket}/${BACKUP_ENV}/${today}.tar.gz  --no-verify-ssl >/dev/null 2>&1 && echo "Successfully copied ${today}.tar.gz to S3!" || echo "Failed to copy ${today}.tar.gz to S3!"

  # copy latest database to top level
  aws s3 cp ./backup_${now}.sql.gz s3://${bucket}/${BACKUP_ENV}/latest.sql.gz  --no-verify-ssl >/dev/null 2>&1 && echo "Successfully copied latest.sql.gz to S3!" || echo "Failed to copy latest.sql.gz to S3!"

  cf delete-service-key "${service}" "${service_key}" -f >/dev/null 2>&1
}

date
