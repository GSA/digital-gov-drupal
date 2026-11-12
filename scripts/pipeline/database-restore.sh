#!/bin/bash

kill_pids() {
  app=$1
  ## pgrep prints bare PIDs. `|| true` because the step runs with -eo pipefail and
  ## the tunnel may already be gone (cf exits on its own once the plugin is killed).
  ids=$(pgrep -f "${app}" || true)
  for id in $ids; do
    kill -9 "${id}" &> /dev/null || true
  done
} &> /dev/null

## Wait for the tunnel to finish connecting.
wait_for_tunnel() {
  while : ; do
    [ -n "$(grep 'Press Control-C to stop.' restore.txt)" ] && break
    ## Fail instead of looping forever if the plugin has exited (its error is on stderr).
    if ! kill -0 "${tunnel_pid}" 2>/dev/null; then
      echo "cf connect-to-service exited before the tunnel was ready."
      exit 1
    fi
    echo "Waiting for tunnel..."
    sleep 1
  done
}


gunzip database_restore.sql.gz

## Create a tunnel through the application to restore the database.
echo "Creating tunnel to database..."
cf connect-to-service --no-client "${PROJECT}-${DATABASE_BACKUP_BASTION_NAME}-${BRANCH}" "${PROJECT}-mysql-${BRANCH}" > restore.txt &
tunnel_pid=$!

wait_for_tunnel

## Create variables and credential file for MySQL login.
echo "Restoring database to '${BRANCH}'..."
{
  host=$(cat restore.txt | grep -i '^host:' | awk '{print $2}')
  port=$(cat restore.txt | grep -i '^port:' | awk '{print $2}')
  username=$(cat restore.txt | grep -i '^username:' | awk '{print $2}')
  password=$(cat restore.txt | grep -i '^password:' | awk '{print $2}')
  dbname=$(cat restore.txt | grep -i '^name:' | awk '{print $2}')

  mkdir ~/.mysql && chmod 0700 ~/.mysql

  echo "[client]" > ~/.mysql/mysql.cnf
  echo "user=${username}" >> ~/.mysql/mysql.cnf
  echo "password=${password}" >> ~/.mysql/mysql.cnf
  chmod 400 ~/.mysql/mysql.cnf
} &> /dev/null

  ## Drop (delete) current database.
  mysql \
  --defaults-extra-file=~/.mysql/mysql.cnf \
  --host="${host}" \
  --port="${port}" \
  --protocol=TCP \
  --execute="DROP DATABASE IF EXISTS ${dbname};"
  
  ## Create a new empty database.
  mysql \
  --defaults-extra-file=~/.mysql/mysql.cnf \
  --host="${host}" \
  --port="${port}" \
  --protocol=TCP \
  --execute="CREATE DATABASE IF NOT EXISTS ${dbname};"

  ## Import data from the backup.
  mysql \
  --defaults-extra-file=~/.mysql/mysql.cnf \
  --host="${host}" \
  --port="${port}" \
  --protocol=TCP \
  --force \
  --database="${dbname}" < database_restore.sql


## Kill the backgrounded SSH tunnel.
echo "Cleaning up old connections..."
{
  kill_pids "connect-to-service"
} &> /dev/null

## Clean up.
rm -rf restore.txt ~/.mysql "backup_${BRANCH}.sql"

