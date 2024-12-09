#!/bin/bash

kill_pids() {
  app=$1
  ids=$(ps aux | grep "${app}" | grep -v grep | awk '{print $2}')
  for id in ${ids}; do
    kill -9 "${id}" &
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
#cf enable-ssh "${PROJECT}-${DATABASE_BACKUP_BASTION_NAME}-${CF_SPACE}"
#cf restart --strategy rolling "${PROJECT}-${DATABASE_BACKUP_BASTION_NAME}-${CF_SPACE}"
cf connect-to-service --no-client "${PROJECT}-${DATABASE_BACKUP_BASTION_NAME}-${CF_SPACE}" "${PROJECT}-mysql-${CF_SPACE}" > backup.txt &

wait_for_tunnel

date

## Create variables and credential file for MySQL login.
echo "Backing up '${CF_SPACE}' database..."
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
    "cache_access_policy"
    "cache_bootstrap"
    "cache_config"
    "cache_container"
    "cache_default"
    "cache_discovery"
    "cache_dynamic_page_cache"
    "cache_entity"
    "cache_menu"
    "cache_page"
    "cache_render"
    "cache_tome_static"
    "cache_toolbar"
    "sessions"
    "watchdog"
  )

  ignored_tables_string=''
  for table in "${excluded_tables[@]}"
  do
    ignored_tables_string+=" --ignore-table=${dbname}.${table}"
  done
} >/dev/null 2>&1

echo "Dumping structure..."
{
  ## Dump structure
  mysqldump \
    --defaults-extra-file=~/.mysql/mysqldump.cnf \
    --host="${host}" \
    --port="${port}" \
    --protocol=TCP \
    --no-data \
    "${dbname}" > "backup_${CF_SPACE}.sql"
} >/dev/null 2>&1

echo "Dumping content..."
{
  ## Dump content
  mysqldump \
    --defaults-extra-file=~/.mysql/mysqldump.cnf \
    --host="${host}" \
    --port="${port}" \
    --protocol=TCP \
    --no-create-info \
    --skip-triggers \
    ${ignored_tables_string} \
    "${dbname}" >> "backup_${CF_SPACE}.sql"

  ## Patch out any MySQL 'SET' commands that require admin.
  sed -i 's/^SET /-- &/' "backup_${CF_SPACE}.sql"
} >/dev/null 2>&1

date

## Kill the backgrounded SSH tunnel.
echo "Cleaning up old connections..."
{
  kill_pids "connect-to-service"
}

## Disable ssh.
#echo "Disabling ssh..."
#cf disable-ssh "${PROJECT}-drupal-${CF_SPACE}"

rm -rf backup.txt ~/.mysql

echo "Compressing '${CF_SPACE}' database..."
{
  mv "backup_${CF_SPACE}.sql" "${TIMESTAMP}.sql"
  gzip "${TIMESTAMP}.sql"
} &> /dev/null

# echo "Creating S3 credentials..."
# {
#   cf target -s "${PROJECT}-${CF_SPACE}" >/dev/null 2>&1

#   service="${PROJECT}-backup-${CF_SPACE}"
#   export service

#   service_key="${service}-key"
#   export service_key

#   cf delete-service-key "${service}" "${service_key}" -f # >/dev/null 2>&1
#   cf create-service-key "${service}" "${service_key}" # >/dev/null 2>&1

#   sleep 2 
# } >/dev/null 2>&1

echo "Setting S3 credentials..."
{
  #s3_credentials=$(cf service-key "${service}" "${service_key}" | tail -n +3)
  s3_credentials=$(cf ssh "${PROJECT}-database-backup-bastion-${CF_SPACE}" -c "env | sort | grep VCAP_SERVICES | sed 's/VCAP_SERVICES=//' | jq -r '.s3[] | select(.name == \"${PROJECT}-backup-${CF_SPACE}\")'")
  export s3_credentials
  
  AWS_ACCESS_KEY_ID=$(echo "${s3_credentials}" | jq -r '.credentials.access_key_id')
  export AWS_ACCESS_KEY_ID

  bucket=$(echo "${s3_credentials}" | jq -r '.credentials.bucket')
  export bucket

  AWS_DEFAULT_REGION=$(echo "${s3_credentials}" | jq -r '.credentials.region')
  export AWS_DEFAULT_REGION

  AWS_SECRET_ACCESS_KEY=$(echo "${s3_credentials}" | jq -r '.credentials.secret_access_key')
  export AWS_SECRET_ACCESS_KEY
} >/dev/null 2>&1

echo "Saving to backup bucket..."
{
  # copy latest database to top level
  #gzip "backup_${CF_SPACE}.sql"
  #aws s3 cp "./backup_${CF_SPACE}.sql.gz" "s3://${bucket}/${CF_SPACE}/latest.sql.gz"  --no-verify-ssl >/dev/null 2>&1 && echo "Successfully copied latest.sql.gz to S3!" || echo "Failed to copy latest.sql.gz to S3!"
  aws s3 cp "${TIMESTAMP}.sql.gz" "s3://${bucket}/$(date +%Y)/$(date +%m)/$(date +%d)/" --no-verify-ssl 2>/dev/null
  aws s3 cp "${TIMESTAMP}.sql.gz" "s3://${bucket}/latest.sql.gz" --no-verify-ssl 2>/dev/null
} >/dev/null 2>&1

# echo "Cleaning up credentials..."
# {
#   cf delete-service-key "${service}" "${service_key}" -f >/dev/null 2>&1
# } >/dev/null 2>&1

date
