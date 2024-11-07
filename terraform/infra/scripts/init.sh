#!/bin/bash

## If a project name is just a dash, no project name was set, so remove the dash.
[ "${prefix}" = "-" ] && prefix=""

echo "Creating terraform backend bucket..."
{
  service="${prefix}terraform-backend"
  service_key="${service}-key"
  cf create-service s3 basic "${service}"
  cf create-service-key "${service}" "${service_key}"
  s3_credentials=$(cf service-key "${service}" "${service_key}" | tail -n +2)
  
  export backend_aws_access_key=$(echo "${s3_credentials}" | jq -r '.credentials.access_key_id')
  export backend_aws_secret_key=$(echo "${s3_credentials}" | jq -r '.credentials.secret_access_key')
  export backend_aws_bucket_name=$(echo "${s3_credentials}" | jq -r '.credentials.bucket')
  export backend_aws_bucket_region=$(echo "${s3_credentials}" | jq -r '.credentials.region')

  envsubst '$backend_aws_bucket_name,$backend_aws_bucket_region' < provider.tf.tmpl > provider.tf
} >/dev/null 2>&1

echo "Creating backup bucket..."
{
  service_backup="${prefix}backup"
  cf create-service s3 basic "${service_backup}"
} >/dev/null 2>&1

./scripts/cloudgov-create-service-account.sh -d ${deploy_space} -o ${org} -p ${prefix} -s ${spaces}