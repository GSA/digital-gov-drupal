#!/bin/bash

## Back up the Cloud.gov database for ${CF_SPACE} and publish it to the backup
## bucket, both as a dated copy and as latest.sql.gz.
##
## This file is *sourced* (not executed) by .github/workflows/daily-backup.yml
## and database-backup-dev.yml, so failures are raised with `die`, which exits
## non-zero and fails the workflow step. It deliberately does NOT use
## `set -eo pipefail`: `kill_pids` runs a grep pipeline that legitimately
## matches nothing once the tunnel is gone, and pipefail would turn that into an
## abort. Checks below are therefore explicit.
##
## Most command output is routed to /dev/null on purpose: backup.txt holds the
## database credentials and `cf service-key` prints the S3 access keys, and all
## of this runs in a CI log. Do NOT unmute these blocks to debug -- failures are
## surfaced through exit-code checks, and any diagnostic that could quote
## command output is passed through `scrub` first.

## Seconds to wait for the SSH tunnel before giving up. Overridable for tests.
TUNNEL_TIMEOUT="${TUNNEL_TIMEOUT:-180}"

## Real stderr, held open so die/scrub can report from inside the muted blocks.
exec 3>&2

## Values that must never reach the log; appended as they are parsed.
declare -a SECRETS=()

## Redact every known secret from stdin before it is echoed to the log.
scrub() {
  local text s
  text="$(cat)"
  for s in "${SECRETS[@]}"; do
    [[ -n "${s}" ]] && text="${text//"${s}"/***REDACTED***}"
  done
  printf '%s\n' "${text}"
}

die() {
  echo "ERROR: $*" >&3
  exit 1
}

kill_pids() {
  app=$1
  ids=$(ps aux | grep "${app}" | grep -v grep | awk '{print $2}')
  for id in ${ids}; do
    kill -9 "${id}" &
  done
}

## Wait for the tunnel to finish connecting, but do not hang the job forever if
## it never does -- before, a tunnel that never came up spun here indefinitely.
wait_for_tunnel() {
  local waited=0
  until grep -q 'Press Control-C to stop.' backup.txt 2>/dev/null; do
    [[ ${waited} -ge ${TUNNEL_TIMEOUT} ]] && \
      die "Timed out after ${TUNNEL_TIMEOUT}s waiting for the database tunnel."
    echo "Waiting for tunnel..."
    sleep 1
    waited=$((waited + 1))
  done
}

## Drop local credential material and the S3 service key on every exit path,
## including the failures added below: an early exit must never leave a live
## access key or a readable password on the runner.
cleanup() {
  local status=$?
  kill_pids "connect-to-service"
  rm -rf backup.txt ~/.mysql
  [[ -n "${DUMP_ERR:-}" ]] && rm -f "${DUMP_ERR}"
  if [[ -n "${SERVICE_INSTANCE_NAME:-}" && -n "${KEY_NAME:-}" ]]; then
    cf delete-service-key "${SERVICE_INSTANCE_NAME}" "${KEY_NAME}" -f >/dev/null 2>&1
  fi
  exec 3>&-
  return ${status}
}
trap cleanup EXIT

## Fail early and legibly rather than building paths like "backup_.sql".
for required in PROJECT CF_SPACE DATABASE_BACKUP_BASTION_NAME TIMESTAMP; do
  [[ -z "${!required:-}" ]] && die "Required environment variable ${required} is not set."
done

backup_file="backup_${CF_SPACE}.sql"
DUMP_ERR="$(mktemp)"

date

## Enable SSH if in prod.
if [[ ${CF_SPACE} = "prod" ]]; then
  echo "Enabling ssh"
  cf allow-space-ssh "${CF_SPACE}"
  cf enable-ssh "${PROJECT}-${DATABASE_BACKUP_BASTION_NAME}-${CF_SPACE}"
  cf restart "${PROJECT}-${DATABASE_BACKUP_BASTION_NAME}-${CF_SPACE}"
fi
## Create a tunnel through the application to pull the database. Left
## unchecked: these are idempotent-ish and may report non-zero when ssh is
## already in the requested state; a genuinely broken tunnel surfaces as the
## wait_for_tunnel timeout above.
echo "Creating tunnel to database..."
cf connect-to-service --no-client "${PROJECT}-${DATABASE_BACKUP_BASTION_NAME}-${CF_SPACE}" "${PROJECT}-mysql-${CF_SPACE}" > backup.txt &

wait_for_tunnel

date

## Disable SSH if in prod -- the existing ssh connection will persist.
if [[ ${CF_SPACE} = "prod" ]]; then
  echo "Connection established; disabling ssh"
  cf disallow-space-ssh "${CF_SPACE}"
  cf disable-ssh "${PROJECT}-${DATABASE_BACKUP_BASTION_NAME}-${CF_SPACE}"
fi

## Create variables and credential file for MySQL login.
echo "Backing up '${CF_SPACE}' database..."
{
  host=$(cat backup.txt | grep -i host | awk '{print $2}')
  port=$(cat backup.txt | grep -i port | awk '{print $2}')
  username=$(cat backup.txt | grep -i username | awk '{print $2}')
  password=$(cat backup.txt | grep -i password | awk '{print $2}')
  dbname=$(cat backup.txt | grep -i '^name' | awk '{print $2}')
} >/dev/null 2>&1

## Validated out here rather than inside the muted block, so a parse failure is
## reported instead of producing a mysqldump that silently connects nowhere.
for field in host port username password dbname; do
  [[ -z "${!field}" ]] && die "Could not parse '${field}' from the tunnel output."
done
SECRETS+=("${password}")

{
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

## Both dumps send stderr to a file rather than /dev/null so a failure can be
## reported (scrubbed) instead of vanishing. stdout is the dump itself.
## ${ignored_tables_string} is intentionally unquoted: it must word-split into
## separate --ignore-table flags.
echo "Dumping structure..."
if ! mysqldump \
      --defaults-extra-file=~/.mysql/mysqldump.cnf \
      --host="${host}" \
      --port="${port}" \
      --protocol=TCP \
      --no-data \
      "${dbname}" > "${backup_file}" 2>"${DUMP_ERR}"; then
  scrub < "${DUMP_ERR}" >&3
  die "mysqldump failed while dumping the schema."
fi

echo "Dumping content..."
if ! mysqldump \
      --defaults-extra-file=~/.mysql/mysqldump.cnf \
      --host="${host}" \
      --port="${port}" \
      --protocol=TCP \
      --no-create-info \
      --skip-triggers \
      ${ignored_tables_string} \
      "${dbname}" >> "${backup_file}" 2>"${DUMP_ERR}"; then
  scrub < "${DUMP_ERR}" >&3
  die "mysqldump failed while dumping table content."
fi

## Patch out any MySQL 'SET' commands that require admin.
sed -i 's/^SET /-- &/' "${backup_file}" || die "Failed to patch SET commands out of the dump."

## A dump can be short even when mysqldump reports success -- e.g. a connection
## dropped mid-stream. mysqldump writes a completion trailer as its final line,
## so require it before publishing: without this check a partial dump is
## compressed, uploaded, and overwrites latest.sql.gz, and nothing anywhere
## says so. scripts/refresh-local.sh makes the same check when importing.
if ! tail -5 "${backup_file}" | grep -q '^-- Dump completed'; then
  die "Dump is incomplete (no mysqldump completion marker); refusing to publish it."
fi

date

## Kill the backgrounded SSH tunnel.
echo "Cleaning up old connections..."
{
  kill_pids "connect-to-service"
}

rm -rf backup.txt ~/.mysql

echo "Compressing '${CF_SPACE}' database..."
mv "${backup_file}" "${TIMESTAMP}.sql" || die "Could not stage the dump for compression."
gzip "${TIMESTAMP}.sql" || die "Failed to compress the dump."
[[ -s "${TIMESTAMP}.sql.gz" ]] || die "Compressed dump is missing or empty."

## SERVICE_INSTANCE_NAME/KEY_NAME are set before the key is created so that the
## cleanup trap can revoke it even if a later step exits early.
echo "Setting S3 credentials..."
SERVICE_INSTANCE_NAME="${PROJECT}-backup-${CF_SPACE}"
KEY_NAME="tmp-key-${SERVICE_INSTANCE_NAME}"
{
  cf create-service-key "${SERVICE_INSTANCE_NAME}" "${KEY_NAME}"
} >/dev/null 2>&1 || die "Could not create the S3 service key for the backup bucket."

{
  S3_CREDENTIALS=$(cf service-key "${SERVICE_INSTANCE_NAME}" "${KEY_NAME}" | tail -n +2)

  export AWS_ACCESS_KEY_ID=$(echo "${S3_CREDENTIALS}" | jq -r '.credentials.access_key_id')
  export AWS_SECRET_ACCESS_KEY=$(echo "${S3_CREDENTIALS}" | jq -r '.credentials.secret_access_key')
  export BUCKET_NAME=$(echo "${S3_CREDENTIALS}" | jq -r '.credentials.bucket')
  export AWS_DEFAULT_REGION=$(echo "${S3_CREDENTIALS}" | jq -r '.credentials.region')
} >/dev/null 2>&1

## jq prints the string "null" for a missing key, which would otherwise reach
## the aws CLI as a literal credential and fail confusingly.
for field in AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY BUCKET_NAME AWS_DEFAULT_REGION; do
  [[ -z "${!field}" || "${!field}" == "null" ]] && \
    die "Could not read '${field}' from the backup bucket's service key."
done
SECRETS+=("${AWS_SECRET_ACCESS_KEY}")

## Error text is intentionally generic: it must not echo the bucket URL.
echo "Saving to backup bucket..."
if ! aws s3 cp "${TIMESTAMP}.sql.gz" "s3://${BUCKET_NAME}/$(date +%Y)/$(date +%m)/$(date +%d)/" \
     --no-verify-ssl >/dev/null 2>&1; then
  die "Failed to upload the dated backup copy."
fi
## Ordered second on purpose: latest.sql.gz is what refresh-local.sh and the
## restore path consume, so it is only advanced once the dated copy is safe.
if ! aws s3 cp "${TIMESTAMP}.sql.gz" "s3://${BUCKET_NAME}/latest.sql.gz" \
     --no-verify-ssl >/dev/null 2>&1; then
  die "Failed to update latest.sql.gz (the dated copy did upload)."
fi

echo "Deleting s3 credentials (service key)"
cf delete-service-key "${SERVICE_INSTANCE_NAME}" "${KEY_NAME}" -f

date
