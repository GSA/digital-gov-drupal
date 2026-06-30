#!/bin/bash

## Shared helpers for working with Cloud Foundry S3 service credentials.
## Intended to be sourced by other pipeline scripts.

## A per-process-invocation suffix, computed once when this file is sourced
## (i.e. in the caller's shell). Subshells -- including the process
## substitution used to capture get_s3_credentials output -- inherit this
## value, so get_s3_credentials and delete_s3_credentials always agree on the
## key name within one invocation, while separate invocations (e.g. the
## parallel storage/static backup jobs that both key the same backup bucket)
## get distinct names and never delete each other's keys.
S3_TMP_KEY_SUFFIX="${S3_TMP_KEY_SUFFIX:-$$-${RANDOM}}"

## Build the temporary service key name for a given service instance.
s3_temp_key_name() {
  echo "tmp-key-$1-${S3_TMP_KEY_SUFFIX}"
}

## Create a temporary service key for an S3 service and echo its credentials as
## space separated values: <access_key> <secret_key> <bucket> <region>
get_s3_credentials() {
  local service_instance_name="$1"
  local key_name
  key_name="$(s3_temp_key_name "${service_instance_name}")"

  cf delete-service-key "${service_instance_name}" "${key_name}" -f >/dev/null 2>&1
  cf create-service-key "${service_instance_name}" "${key_name}" >/dev/null 2>&1

  local s3_credentials
  s3_credentials=$(cf service-key "${service_instance_name}" "${key_name}" | tail -n +2)

  local access_key secret_key bucket region
  access_key=$(echo "${s3_credentials}" | jq -r '.credentials.access_key_id')
  secret_key=$(echo "${s3_credentials}" | jq -r '.credentials.secret_access_key')
  bucket=$(echo "${s3_credentials}" | jq -r '.credentials.bucket')
  region=$(echo "${s3_credentials}" | jq -r '.credentials.region')

  echo "${access_key} ${secret_key} ${bucket} ${region}"
}

## Delete a temporary service key created by get_s3_credentials.
delete_s3_credentials() {
  local service_instance_name="$1"
  local key_name
  key_name="$(s3_temp_key_name "${service_instance_name}")"
  cf delete-service-key "${service_instance_name}" "${key_name}" -f >/dev/null 2>&1
}
