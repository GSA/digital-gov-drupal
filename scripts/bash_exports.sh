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
 
S3_BUCKET=$(echo "${VCAP_SERVICES}" | jq -r '.["s3"][]? | select(.name == "storage") | .credentials.bucket')
export S3_BUCKET

S3_ENDPOINT=$(echo "${VCAP_SERVICES}" | jq -r '.["s3"][]? | select(.name == "storage") | .credentials.fips_endpoint')
export S3_ENDPOINT

SPACE=$(echo "${VCAP_APPLICATION}" | jq -r '.["space_name"]')
export SPACE

WWW_HOST=${WWW_HOST:-$(echo "${VCAP_APPLICATION}" | jq -r '.["application_uris"][]' | grep 'beta\|www' | tr '\n' ' ')}
export WWW_HOST

CMS_HOST=${CMS_HOST:-$(echo "${VCAP_APPLICATION}" | jq -r '.["application_uris"][]' | grep cms | tr '\n' ' ')}
export CMS_HOST

if [ -z "$WWW_HOST" ]; then
  WWW_HOST="*.app.cloud.gov"
  export WWW_HOST
elif [ -z "$CMS_HOST" ]; then
  CMS_HOST=$(echo "${VCAP_APPLICATION}" | jq -r '.["application_uris"][]' | head -n 1)
  export CMS_HOST
fi

S3_ROOT_WEB=${S3_ROOT_WEB:-/web}
export S3_ROOT_WEB

S3_ROOT_CMS=${S3_ROOT_CMS:-/cms/public}
export S3_ROOT_CMS

S3_HOST=${S3_HOST:-$S3_BUCKET.$S3_ENDPOINT}
export S3_HOST

S3_PROXY_WEB=${S3_PROXY_WEB:-$S3_HOST$S3_ROOT_WEB}
export S3_PROXY_WEB

S3_PROXY_CMS=${S3_PROXY_CMS:-$S3_HOST$S3_ROOT_CMS}
export S3_PROXY_CMS

S3_PROXY_PATH_CMS=${S3_PROXY_PATH_CMS:-/s3/files}
export S3_PROXY_PATH_CMS

DNS_SERVER=${DNS_SERVER:-$(grep -i '^nameserver' /etc/resolv.conf|head -n1|cut -d ' ' -f2)}
export DNS_SERVER
