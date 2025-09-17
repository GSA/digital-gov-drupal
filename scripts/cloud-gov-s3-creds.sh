#!/bin/bash

## Get current username with no special characters.
user=$(whoami | tr -dc '[:alnum:]\n\r' | tr '[:upper:]' '[:lower:]')

if [ -z "${bucket_name}" ]; then
  echo -e "Error: No bucket name is set!\n"
  echo -e "Export the bucket name, found with 'cf services | grep s3', then run the script again."
  echo -e "This is the name of the bucket in cloud.gov, not the AWS bucket name.\n"
  echo -e "Example usage:\n\texport bucket_name=project-bucket-name-environment\n\t$0\n"
  return
fi

if [ -n "$(cf orgs | grep FAILED)" ]; then
  return
fi

echo "Deleting old credentials..."
{
  service_key="${bucket_name}-${user}-key"

  ## Delete any old keys.
  cf delete-service-key "${bucket_name}" "${service_key}" -f
} >/dev/null 2>&1

[ "${1}" = "-d" ] && echo "AWS bucket key deleted." && return

echo "Creating key..."
{
  cf create-service-key "${bucket_name}" "${service_key}"
  s3_credentials=$(cf service-key "${bucket_name}" "${service_key}" | tail -n +2)
  aws_access_key=$(echo "${s3_credentials}" | jq -r '.credentials.access_key_id')
  aws_bucket_name=$(echo "${s3_credentials}" | jq -r '.credentials.bucket')
  aws_bucket_region=$(echo "${s3_credentials}" | jq -r '.credentials.region')
  aws_secret_key=$(echo "${s3_credentials}" | jq -r '.credentials.secret_access_key')

  declare AWS_ACCESS_KEY_ID
  export AWS_ACCESS_KEY_ID=${aws_access_key}

  declare AWS_BUCKET
  export AWS_BUCKET=${aws_bucket_name}

  declare AWS_DEFAULT_REGION
  export AWS_DEFAULT_REGION=${aws_bucket_region}

  declare AWS_SECRET_ACCESS_KEY
  export AWS_SECRET_ACCESS_KEY=${aws_secret_key}

  cat >~/current_creds.sh << EOT
export AWS_ACCESS_KEY_ID="${aws_access_key}"
export AWS_BUCKET="${aws_bucket_name}"
export AWS_DEFAULT_REGION="${aws_bucket_region}"
export AWS_SECRET_ACCESS_KEY="${aws_secret_key}"
EOT
chmod +x ~/current_creds.sh
} >/dev/null 2>&1

if [ -z "${AWS_ACCESS_KEY_ID}" ]; then
  echo -e "Error setting AWS credentials."
  echo -e "Please ensure you're logged in to Cloud.gov."
  echo -e "You can check by running: cf target -s <space_name>"

  ## `CI` is set to true in GitHub action pipelines. So if it's empty, just return so it doesn't exit the terminal.
  [ -z "${CI}" ] && return

  exit 1
fi
