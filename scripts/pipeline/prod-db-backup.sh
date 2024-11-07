#!/bin/bash
if [ ${CIRCLE_BRANCH} != 'prod' ]; then
  echo "This script is for backing up the prod database only."
  exit 1
fi

kill_pids() {
  app=$1
  ids=$(ps aux | grep ${app} | grep -v grep | awk '{print $2}')
  for id in ${ids}; do
    kill -9 ${id} >/dev/null 2>&1
  done
}

## Wait for the tunnel to finish connecting.
wait_for_tunnel() {
  while : ; do
    [ -n "$(grep 'Press Control-C to stop.' backup.txt)" ] && break
    echo "Waiting for tunnel..."
    sleep 1
  done
}

date

## Create a tunnel through the application to pull the database.
echo "Creating tunnel to database..."
cf enable-ssh ${project}-drupal-prod
cf restart --strategy rolling ${project}-drupal-prod
cf connect-to-service --no-client ${project}-drupal-prod ${project}-mysql-prod > backup.txt &

wait_for_tunnel

date

## Create variables and credential file for MySQL login.
echo "Backing up 'prod' database..."
{
  host=$(cat backup.txt | grep -i host | awk '{print $2}')
  port=$(cat backup.txt | grep -i port | awk '{print $2}')
  username=$(cat backup.txt | grep -i username | awk '{print $2}')
  password=$(cat backup.txt | grep -i password | awk '{print $2}')
  dbname=$(cat backup.txt | grep -i '^name' | awk '{print $2}')

  mkdir ~/.mysql && chmod 0700 ~/.mysql

  echo "[mysqldump]" > ~/.mysql/mysqldump.cnf
  echo "user=${username}" >> ~/.mysql/mysqldump.cnf
  echo "password=${password}" >> ~/.mysql/mysqldump.cnf
  chmod 400 ~/.mysql/mysqldump.cnf

  ## Exclude tables without data
  declare -a excluded_tables=(
    "cache_advagg_minify"
    "cache_bootstrap"
    "cache_config"
    "cache_container"
    "cache_data"
    "cache_default"
    "cache_discovery"
    "cache_discovery_migration"
    "cache_dynamic_page_cache"
    "cache_entity"
    "cache_menu"
    "cache_migrate"
    "cache_page"
    "cache_render"
    "cache_rest"
    "cache_toolbar"
    "sessions"
    "watchdog"
    "webprofiler"
  )

  ignored_tables_string=''
  for table in "${excluded_tables[@]}"
  do
    ignored_tables_string+=" --ignore-table=${dbname}.${table}"
  done

  ## Dump structure
  mysqldump \
    --defaults-extra-file=~/.mysql/mysqldump.cnf \
    --host=${host} \
    --port=${port} \
    --protocol=TCP \
    --no-data \
    ${dbname} > backup_prod.sql

  ## Dump content
  mysqldump \
    --defaults-extra-file=~/.mysql/mysqldump.cnf \
    --host=${host} \
    --port=${port} \
    --protocol=TCP \
    --no-create-info \
    --skip-triggers \
    ${ignored_tables_string} \
    ${dbname} >> backup_prod.sql

  ## Patch out any MySQL 'SET' commands that require admin.
  sed -i 's/^SET /-- &/' backup_prod.sql

} >/dev/null 2>&1

date

## Kill the backgrounded SSH tunnel.
echo "Cleaning up old connections..."
{
  kill_pids "connect-to-service"
} >/dev/null 2>&1

## Disable ssh.
echo "Disabling ssh..."
cf disable-ssh ${project}-drupal-prod

rm -rf backup.txt ~/.mysql

echo "Saving to backup bucket..."
{
  cf target -s "${project}-prod" >/dev/null 2>&1

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

  # copy latest database to top level
  gzip backup_prod.sql
  aws s3 cp ./backup_prod.sql.gz s3://${bucket}/prod/latest.sql.gz  --no-verify-ssl >/dev/null 2>&1 && echo "Successfully copied latest.sql.gz to S3!" || echo "Failed to copy latest.sql.gz to S3!"

  cf delete-service-key "${service}" "${service_key}" -f >/dev/null 2>&1
}

date
