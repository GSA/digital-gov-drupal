#!/bin/bash
if [ ${RESTORE_ENV} = 'prod' ]; then
  echo "Restoring to prod is not allowed."
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
    [ -n "$(grep 'Press Control-C to stop.' restore.txt)" ] && break
    echo "Waiting for tunnel..."
    sleep 1
  done
}

date

## Download latest prod backup.
echo "Downloading latest prod database backup..."
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

  # copy latest database from top level
  aws s3 cp s3://${bucket}/prod/latest.sql.gz ./latest.sql.gz --no-verify-ssl >/dev/null 2>&1 && echo "Successfully copied latest.sql.gz from S3!" || echo "Failed to copy latest.sql.gz from S3!"
  gunzip latest.sql.gz

  cf delete-service-key "${service}" "${service_key}" -f >/dev/null 2>&1
}

date

## Create a tunnel through the application to restore the database.
echo "Creating tunnel to database..."
if [ ${RESTORE_ENV} = 'test' ]; then
  cf target -s "${project}-dev" >/dev/null 2>&1
else
  cf target -s "${project}-${RESTORE_ENV}" >/dev/null 2>&1
fi
cf connect-to-service --no-client ${project}-drupal-${RESTORE_ENV} ${project}-mysql-${RESTORE_ENV} > restore.txt &

wait_for_tunnel

date

## Create variables and credential file for MySQL login.
echo "Restoring 'prod' database to '${RESTORE_ENV}'..."
{
  host=$(cat restore.txt | grep -i host | awk '{print $2}')
  port=$(cat restore.txt | grep -i port | awk '{print $2}')
  username=$(cat restore.txt | grep -i username | awk '{print $2}')
  password=$(cat restore.txt | grep -i password | awk '{print $2}')
  dbname=$(cat restore.txt | grep -i '^name' | awk '{print $2}')

  mkdir ~/.mysql && chmod 0700 ~/.mysql

  echo "[client]" > ~/.mysql/mysql.cnf
  echo "user=${username}" >> ~/.mysql/mysql.cnf
  echo "password=${password}" >> ~/.mysql/mysql.cnf
  chmod 400 ~/.mysql/mysql.cnf

  mysql \
  --defaults-extra-file=~/.mysql/mysql.cnf \
  --host=${host} \
  --port=${port} \
  --protocol=TCP \
  --database=${dbname} < latest.sql

} >/dev/null 2>&1

date

## Kill the backgrounded SSH tunnel.
echo "Cleaning up old connections..."
{
  kill_pids "connect-to-service"
} >/dev/null 2>&1

## Clean up.
rm -rf restore.txt ~/.mysql latest.sql

date

echo "Running 'drush cr' on '${RESTORE_ENV}' database..."
source $(pwd $(dirname $0))/scripts/pipeline/cloud-gov-remote-command.sh "${project}-drupal-${RESTORE_ENV}" "drush cr"

date

echo "Running 'drush image-flush --all' on '${RESTORE_ENV}'..."
source $(pwd $(dirname $0))/scripts/pipeline/cloud-gov-remote-command.sh "${project}-drupal-${RESTORE_ENV}" "drush image-flush --all"

date
