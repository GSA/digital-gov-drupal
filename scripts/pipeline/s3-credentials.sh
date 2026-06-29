#!/bin/bash

## Shared helpers for working with Cloud Foundry S3 service credentials.
## Intended to be sourced by other pipeline scripts.

## Create a temporary service key for an S3 service and echo its credentials as
## space separated values: <access_key> <secret_key> <bucket> <region>
get_s3_credentials() {
  local service_instance_name="$1"
  local key_name="tmp-key-${service_instance_name}"

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
  local key_name="tmp-key-${service_instance_name}"
  cf delete-service-key "${service_instance_name}" "${key_name}" -f >/dev/null 2>&1
}
