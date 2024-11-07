#!/bin/bash

home="/home/vcap"

#app_path="${home}/app"

PG_CONN_STR=$(echo "${VCAP_SERVICES}" | jq '."aws-rds"[].credentials.uri')
PGDATABASE=$(echo "${VCAP_SERVICES}" | jq '."aws-rds"[].credentials.db_name')
PGHOST=$(echo "${VCAP_SERVICES}" | jq '."aws-rds"[].credentials.host')
PGPASSWORD=$(echo "${VCAP_SERVICES}" | jq '."aws-rds"[].credentials.password')
PGPORT=$(echo "${VCAP_SERVICES}" | jq '."aws-rds"[].credentials.port')
PGUSER=$(echo "${VCAP_SERVICES}" | jq '."aws-rds"[].credentials.username')

{
  echo "export PATH=${PATH}:${home}/deps/0/bin" | tee "${home}/exports.sh" 
  echo "alias terraform=tofu" | tee -a "${home}/exports.sh" 
  echo "alias tf=tofu" | tee -a "${home}/exports.sh" 
  
  echo "export PG_CONN_STR=${PG_CONN_STR}" | tee -a "${home}/exports.sh" 
  echo "export PGDATABASE=${PGDATABASE}" | tee -a "${home}/exports.sh" 
  echo "export PGHOST=${PGHOST}" | tee -a "${home}/exports.sh" 
  echo "export PGPASSWORD=${PGPASSWORD}" | tee -a "${home}/exports.sh" 
  echo "export PGPORT=${PGPORT}" | tee -a "${home}/exports.sh" 
  echo "export PGUSER=${PGUSER}" | tee -a "${home}/exports.sh" 
} > /dev/null 2>&1

