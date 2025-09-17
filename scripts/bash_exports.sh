#! /bin/bash

# SECRETS=$(echo "${VCAP_SERVICES}" | jq -r '.["user-provided"][] | select(.name == "secrets") | .credentials')
# export SECRETS

# SECAUTHSECRETS=$(echo "${VCAP_SERVICES}" | jq -r '.["user-provided"][] | select(.name == "secauthsecrets") | .credentials')
# export SECAUTHSECRETS

APP_NAME=$(echo "${VCAP_APPLICATION}" | jq -r '.name')
export APP_NAME

APP_ROOT=$(dirname "$0")
export APP_ROOT

APP_ID=$(echo "${VCAP_APPLICATION}" | jq -r '.application_id')
export APP_ID

DB_NAME=$(echo "${VCAP_SERVICES}" | jq -r '.["aws-rds"][] | .credentials.db_name')
export DB_NAME

DB_USER=$(echo "${VCAP_SERVICES}" | jq -r '.["aws-rds"][] | .credentials.username')
export DB_USER

DB_PW=$(echo "${VCAP_SERVICES}" | jq -r '.["aws-rds"][] | .credentials.password')
export DB_PW

DB_HOST=$(echo "${VCAP_SERVICES}" | jq -r '.["aws-rds"][] | .credentials.host')
export DB_HOST

DB_PORT=$(echo "${VCAP_SERVICES}" | jq -r '.["aws-rds"][] | .credentials.port')
export DB_PORT

# ADMIN_EMAIL=$(echo "${SECRETS}" | jq -r '.ADMIN_EMAIL')
# export ADMIN_EMAIL

ENV=$(echo "${VCAP_APPLICATION}" | jq -r '.space_name' | rev | cut -d- -f1 | rev)
export ENV

S3_STORAGE_BUCKET=$(echo "${VCAP_SERVICES}" | jq -r '."s3"[] | select( .name | contains("storage")) | .credentials.bucket')
export S3_STORAGE_BUCKET

S3_STORAGE_ENDPOINT=$(echo "${VCAP_SERVICES}" | jq -r '."s3"[] | select( .name | contains("storage")) | .credentials.fips_endpoint')
export S3_STORAGE_ENDPOINT

S3_STORAGE_ACCESS_KEY_ID=$(echo "${VCAP_SERVICES}" | jq -r '."s3"[] | select( .name | contains("storage")) | .credentials.access_key_id')
export S3_STORAGE_ACCESS_KEY_ID

S3_STORAGE_SECRET_ACCESS_KEY=$(echo "${VCAP_SERVICES}" | jq -r '."s3"[] | select( .name | contains("storage")) | .credentials.secret_access_key')
export S3_STORAGE_SECRET_ACCESS_KEY

S3_STORAGE_REGION=$(echo "${VCAP_SERVICES}" | jq -r '."s3"[] | select( .name | contains("storage")) | .credentials.region')
export S3_STORAGE_REGION


S3_STATIC_BUCKET=$(echo "${VCAP_SERVICES}" | jq -r '."s3"[] | select( .name | contains("static")) | .credentials.bucket')
export S3_STATIC_BUCKET

S3_STATIC_ENDPOINT=$(echo "${VCAP_SERVICES}" | jq -r '."s3"[] | select( .name | contains("static")) | .credentials.fips_endpoint')
export S3_STATIC_ENDPOINT

S3_STATIC_ACCESS_KEY_ID=$(echo "${VCAP_SERVICES}" | jq -r '."s3"[] | select( .name | contains("static")) | .credentials.access_key_id')
export S3_STATIC_ACCESS_KEY_ID

S3_STATIC_SECRET_ACCESS_KEY=$(echo "${VCAP_SERVICES}" | jq -r '."s3"[] | select( .name | contains("static")) | .credentials.secret_access_key')
export S3_STATIC_SECRET_ACCESS_KEY

S3_STATIC_REGION=$(echo "${VCAP_SERVICES}" | jq -r '."s3"[] | select( .name | contains("static")) | .credentials.region')
export S3_STATIC_REGION


SPACE=$(echo "${VCAP_APPLICATION}" | jq -r '.["space_name"]')
export SPACE

WWW_HOST=${WWW_HOST:-$(echo "${VCAP_APPLICATION}" | jq -r '.["application_uris"][]' | grep 'beta\|www' | tr '\n' ' ')}
export WWW_HOST

CMS_HOST=${CMS_HOST:-$(echo "${VCAP_APPLICATION}" | jq -r '.["application_uris"][]' | grep cms | tr '\n' ' ')}
export CMS_HOST

S3_ROOT_WEB=${S3_ROOT_WEB:-/web}
export S3_ROOT_WEB

S3_ROOT_CMS=${S3_ROOT_CMS:-/cms/public}
export S3_ROOT_CMS

S3_STORAGE_HOST=${S3_STORAGE_HOST:-$S3_STORAGE_BUCKET.$S3_STORAGE_ENDPOINT}
export S3_STORAGE_HOST

S3_STATIC_HOST=${S3_STATIC_HOST:-$S3_STATIC_BUCKET.$S3_STATIC_ENDPOINT}
export S3_STATIC_HOST