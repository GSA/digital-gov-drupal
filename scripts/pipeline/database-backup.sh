#!/bin/bash
## Sourced from the "Backup Database" workflow step, which runs under
## `bash -e -o pipefail`: any failing command ends the step, so cleanup lives
## in an EXIT trap rather than at the bottom of the script.

BASTION_APP="${PROJECT}-${DATABASE_BACKUP_BASTION_NAME}-${CF_SPACE}"
SERVICE_INSTANCE_NAME="${PROJECT}-backup-${CF_SPACE}"
KEY_NAME="tmp-key-${SERVICE_INSTANCE_NAME}"
SSH_ENABLED=0
KEY_CREATED=0

## Retry a command up to N times, 10 seconds apart.
retry() {
  local attempts=$1
  shift
  local n=1
  until "$@"; do
    if (( n >= attempts )); then
      echo "Failed after ${attempts} attempts: $*"
      return 1
    fi
    echo "Attempt ${n}/${attempts} failed; retrying in 10s..."
    sleep 10
    n=$((n + 1))
  done
}

disable_ssh() {
  echo "Disabling ssh"
  cf disallow-space-ssh "${CF_SPACE}"
  cf disable-ssh "${BASTION_APP}"
  SSH_ENABLED=0
}

## Runs on every exit, success or failure.
cleanup() {
  local status=$?
  set +e
  echo "Cleaning up..."
  pkill -f "connect-to-service" >/dev/null 2>&1
  if (( SSH_ENABLED )); then
    disable_ssh
  fi
  if (( KEY_CREATED )); then
    echo "Deleting s3 credentials (service key)"
    cf delete-service-key "${SERVICE_INSTANCE_NAME}" "${KEY_NAME}" -f
  fi
  rm -rf backup.txt ~/.mysql
  date
  if (( status != 0 )); then
    echo "::error::Database backup failed (exit code ${status})."
  fi
  exit "${status}"
}
trap cleanup EXIT

## Wait for the tunnel to finish connecting.
wait_for_tunnel() {
  local tries=0
  until grep -q 'Press Control-C to stop.' backup.txt 2>/dev/null; do
    if ! kill -0 "${TUNNEL_PID}" 2>/dev/null; then
      echo "Tunnel process exited before connecting:"
      cat backup.txt
      return 1
    fi
    if (( ++tries > 120 )); then
      echo "Timed out waiting for tunnel."
      return 1
    fi
    echo "Waiting for tunnel..."
    sleep 1
  done
}

date

## Enable SSH if in prod.
if [[ ${CF_SPACE} = "prod" ]]; then
  echo "Enabling ssh"
  SSH_ENABLED=1
  cf allow-space-ssh "${CF_SPACE}"
  cf enable-ssh "${BASTION_APP}"
  cf restart "${BASTION_APP}"
fi

## Create a tunnel through the application to pull the database.
echo "Creating tunnel to database..."
cf connect-to-service --no-client "${BASTION_APP}" "${PROJECT}-mysql-${CF_SPACE}" > backup.txt &
TUNNEL_PID=$!

wait_for_tunnel

date

## Disable SSH if in prod -- the existing ssh connection will persist.
if (( SSH_ENABLED )); then
  echo "Connection established"
  disable_ssh
fi

## Create variables and credential file for MySQL login.
echo "Backing up '${CF_SPACE}' database..."
{
  host=$(grep -i host backup.txt | awk '{print $2}')
  port=$(grep -i port backup.txt | awk '{print $2}')
  username=$(grep -i username backup.txt | awk '{print $2}')
  password=$(grep -i password backup.txt | awk '{print $2}')
  dbname=$(grep -i '^name' backup.txt | awk '{print $2}')

  mkdir -p ~/.mysql && chmod 0700 ~/.mysql

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

## mysqldump stdout goes to the file; stderr is left visible so failures show
## up in the job log.
echo "Dumping structure..."
mysqldump \
  --defaults-extra-file=~/.mysql/mysqldump.cnf \
  --host="${host}" \
  --port="${port}" \
  --protocol=TCP \
  --no-data \
  "${dbname}" > "backup_${CF_SPACE}.sql"

echo "Dumping content..."
mysqldump \
  --defaults-extra-file=~/.mysql/mysqldump.cnf \
  --host="${host}" \
  --port="${port}" \
  --protocol=TCP \
  --no-create-info \
  --skip-triggers \
  ${ignored_tables_string} \
  "${dbname}" >> "backup_${CF_SPACE}.sql"

## A complete dump ends with mysqldump's "-- Dump completed" trailer.
if ! tail -n 1 "backup_${CF_SPACE}.sql" | grep -q '^-- Dump completed'; then
  echo "Dump looks incomplete: missing '-- Dump completed' trailer."
  exit 1
fi

## Patch out any MySQL 'SET' commands that require admin.
sed -i 's/^SET /-- &/' "backup_${CF_SPACE}.sql"

date

## The tunnel is no longer needed.
pkill -f "connect-to-service" >/dev/null 2>&1 || true
rm -rf backup.txt ~/.mysql

echo "Compressing '${CF_SPACE}' database..."
mv -f "backup_${CF_SPACE}.sql" "${TIMESTAMP}.sql"
gzip "${TIMESTAMP}.sql"
gzip -t "${TIMESTAMP}.sql.gz"
ls -lh "${TIMESTAMP}.sql.gz"

echo "Setting S3 credentials..."
## Start from a fresh key; a failed run may have left one behind.
cf delete-service-key "${SERVICE_INSTANCE_NAME}" "${KEY_NAME}" -f >/dev/null 2>&1 || true
KEY_CREATED=1
cf create-service-key "${SERVICE_INSTANCE_NAME}" "${KEY_NAME}" >/dev/null
{
  S3_CREDENTIALS=$(cf service-key "${SERVICE_INSTANCE_NAME}" "${KEY_NAME}" | tail -n +2)

  export AWS_ACCESS_KEY_ID=$(echo "${S3_CREDENTIALS}" | jq -r '.credentials.access_key_id')
  export AWS_SECRET_ACCESS_KEY=$(echo "${S3_CREDENTIALS}" | jq -r '.credentials.secret_access_key')
  export BUCKET_NAME=$(echo "${S3_CREDENTIALS}" | jq -r '.credentials.bucket')
  export AWS_DEFAULT_REGION=$(echo "${S3_CREDENTIALS}" | jq -r '.credentials.region')
} >/dev/null 2>&1
unset S3_CREDENTIALS

for var in AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY BUCKET_NAME AWS_DEFAULT_REGION; do
  if [[ -z "${!var}" || "${!var}" = "null" ]]; then
    echo "Could not read ${var} from service key ${KEY_NAME}."
    exit 1
  fi
done

## A newly created service key can take a little while before AWS accepts it,
## so retry the uploads instead of failing on the first attempt.
echo "Saving to backup bucket..."
DATED_PATH="${TIMESTAMP:0:4}/${TIMESTAMP:5:2}/${TIMESTAMP:8:2}/${TIMESTAMP}.sql.gz"
retry 9 aws s3 cp "${TIMESTAMP}.sql.gz" "s3://${BUCKET_NAME}/${DATED_PATH}" --only-show-errors
retry 3 aws s3 cp "s3://${BUCKET_NAME}/${DATED_PATH}" "s3://${BUCKET_NAME}/latest.sql.gz" --only-show-errors
echo "Saved s3://<backup bucket>/${DATED_PATH} and latest.sql.gz"
