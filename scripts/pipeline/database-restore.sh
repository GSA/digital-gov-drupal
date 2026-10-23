#!/bin/bash

## Replace the Cloud.gov database for ${CF_SPACE} with database_restore.sql.gz
## (as downloaded by s3-backup-download.sh), through that space's bastion.
##
## This file is *sourced* by .github/workflows/database-restore.yml and
## downsync.yml. As in database-backup.sh, failures are raised with `die`,
## and output that could carry credentials or database content is kept out of
## the CI log.

## Seconds to wait for the SSH tunnel before giving up. Overridable for tests.
TUNNEL_TIMEOUT="${TUNNEL_TIMEOUT:-180}"

## Real stderr, held open so die can report from inside the muted blocks.
exec 3>&2

die() {
  echo "ERROR: $*" >&3
  exit 1
}

## Stop a process and everything it started, children first. The tunnel is
## `cf`, which runs the service-connect plugin, which may run its own ssh.
kill_tree() {
  local child
  for child in $(pgrep -P "$1" 2>/dev/null || true); do
    kill_tree "${child}"
  done
  kill "$1" 2>/dev/null || true
}

## Stop the tunnel this script started, and no other: this also runs on
## developers' computers, via scripts/downsync.sh.
stop_tunnel() {
  [[ -n "${TUNNEL_PID:-}" ]] || return 0
  kill_tree "${TUNNEL_PID}"
  TUNNEL_PID=""
}

## Wait for the tunnel to finish connecting, but not forever.
wait_for_tunnel() {
  local waited=0
  until grep -q 'Press Control-C to stop.' restore.txt 2>/dev/null; do
    [[ ${waited} -ge ${TUNNEL_TIMEOUT} ]] && \
      die "Timed out after ${TUNNEL_TIMEOUT}s waiting for the database tunnel."
    echo "Waiting for tunnel..."
    sleep 1
    waited=$((waited + 1))
  done
}

## Print a "Key: value" field from the tunnel's connection details. awk rather
## than a grep pipeline, so a missing field is reported below instead of
## tripping pipefail inside a muted block.
tunnel_field() {
  awk -v key="$1:" 'tolower($1) == key {print $2}' restore.txt
}

## mysql error lines quote the failing SQL, which here is production data, so
## only the error code and dump line number are logged.
report_mysql_errors() {
  sed -n 's/^\(ERROR [0-9]* ([0-9A-Z]*)\( at line [0-9]*\)\{0,1\}\).*/\1/p' "${MYSQL_ERR}" | head -10 >&3
}

## Prod's space keeps SSH off. It is opened only while the tunnel starts, as
## in database-backup.sh, and closed here too in case a failure comes first.
close_prod_ssh() {
  [[ -n "${prod_ssh_open:-}" ]] || return 0
  echo "Disabling ssh"
  cf disallow-space-ssh "${CF_SPACE}" >/dev/null 2>&1 || true
  cf disable-ssh "${bastion}" >/dev/null 2>&1 || true
  prod_ssh_open=""
}

cleanup() {
  local status=$?
  close_prod_ssh
  stop_tunnel
  rm -f restore.txt database_restore.sql
  [[ -n "${MYSQL_DIR:-}" ]] && rm -rf "${MYSQL_DIR}"
  [[ -n "${MYSQL_ERR:-}" ]] && rm -f "${MYSQL_ERR}"
  exec 3>&-
  return ${status}
}
trap cleanup EXIT

for required in PROJECT CF_SPACE DATABASE_BACKUP_BASTION_NAME; do
  [[ -z "${!required:-}" ]] && die "Required environment variable ${required} is not set."
done

MYSQL_ERR="$(mktemp)"
## mktemp -d creates it readable by this user only.
MYSQL_DIR="$(mktemp -d)"
mysql_cnf="${MYSQL_DIR}/mysql.cnf"
bastion="${PROJECT}-${DATABASE_BACKUP_BASTION_NAME}-${CF_SPACE}"

date

[[ -s database_restore.sql.gz ]] || die "database_restore.sql.gz is missing or empty."
gunzip -f database_restore.sql.gz || die "Failed to decompress database_restore.sql.gz."

## Checked before anything is dropped. A dump cut short still decompresses, and
## restoring it would leave ${CF_SPACE} with part of a database.
## database-backup.sh makes the same check before publishing.
if ! tail -5 database_restore.sql | grep -q '^-- Dump completed'; then
  die "Dump is incomplete (no mysqldump completion marker); refusing to restore it."
fi

## Unchecked, as in database-backup.sh: a tunnel that can't open shows up as
## the wait_for_tunnel timeout.
if [[ ${CF_SPACE} = "prod" ]]; then
  echo "Enabling ssh"
  prod_ssh_open=1
  cf allow-space-ssh "${CF_SPACE}" || true
  cf enable-ssh "${bastion}" || true
  cf restart "${bastion}" || true
fi

## Create a tunnel through the bastion to restore the database.
echo "Creating tunnel to database..."
cf connect-to-service --no-client "${bastion}" "${PROJECT}-mysql-${CF_SPACE}" > restore.txt &
TUNNEL_PID=$!

wait_for_tunnel

## The established tunnel persists after SSH is disabled.
close_prod_ssh

date

host=$(tunnel_field host)
port=$(tunnel_field port)
username=$(tunnel_field username)
password=$(tunnel_field password)
dbname=$(tunnel_field name)

for field in host port username password dbname; do
  [[ -z "${!field}" ]] && die "Could not parse '${field}' from the tunnel output."
done

{
  echo "[client]" > "${mysql_cnf}"
  echo "user=${username}" >> "${mysql_cnf}"
  echo "password=${password}" >> "${mysql_cnf}"
  chmod 400 "${mysql_cnf}"
} >/dev/null 2>&1

run_mysql() {
  mysql \
    --defaults-extra-file="${mysql_cnf}" \
    --host="${host}" \
    --port="${port}" \
    --protocol=TCP \
    "$@" 2>"${MYSQL_ERR}"
}

echo "Restoring database to '${CF_SPACE}'..."

## Drop (delete) current database.
if ! run_mysql --execute="DROP DATABASE IF EXISTS \`${dbname}\`;"; then
  report_mysql_errors
  die "Could not drop the '${CF_SPACE}' database."
fi

## Create a new empty database.
if ! run_mysql --execute="CREATE DATABASE IF NOT EXISTS \`${dbname}\`;"; then
  report_mysql_errors
  die "Could not create the '${CF_SPACE}' database; it is currently missing."
fi

## Import data from the backup. --force keeps going past a bad statement so
## one error doesn't leave a half-empty database, but any error still fails
## the step: the restore needs a look before anyone relies on it.
import_status=0
run_mysql --force --database="${dbname}" < database_restore.sql || import_status=$?
if [[ ${import_status} -ne 0 ]] || grep -q '^ERROR' "${MYSQL_ERR}"; then
  report_mysql_errors
  die "The import reported errors; the '${CF_SPACE}' database may be incomplete."
fi

date

## Kill the backgrounded SSH tunnel.
echo "Cleaning up old connections..."
stop_tunnel
rm -rf restore.txt "${MYSQL_DIR}" database_restore.sql

echo "Restored '${CF_SPACE}' database."
