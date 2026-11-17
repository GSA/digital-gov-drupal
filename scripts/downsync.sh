#!/bin/bash

## Copy one Cloud.gov space's database and public files into another space,
## overwriting what's there. Usually that's refreshing staging or dev from prod.
##
## Runs from a developer's computer, and is what .github/workflows/downsync.yml
## runs, so both do the same steps. From a computer, log in first:
##
##   cf login -a api.fr.cloud.gov --sso
##   ./scripts/downsync.sh -s prod -t staging
##
## -h lists the options. See docs/runbooks/github/downsync.yml.MD.

set -eo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PIPELINE="${REPO_ROOT}/scripts/pipeline"

usage() {
  cat <<EOF
Usage: $(basename "$0") -s <source> -t <target> [options]

Overwrites <target>'s database and public files with <source>'s, then runs
drush deploy on <target> and regenerates its static site.
Spaces: dev, staging, prod.

Options:
  -s, --source SPACE        Space to copy from (default: prod).
  -t, --target SPACE        Space to overwrite. Required.
      --database-only       Leave the target's public files alone.
      --files-only          Leave the target's database alone.
      --use-latest-backup   Copy the source's most recent backup instead of
                            backing it up now. Only prod is backed up nightly.
      --database-file PATH  Copy this dump from the source's backup bucket.
      --files-file PATH     Copy this files archive from the source's backup bucket.
      --no-target-backup    Don't back up the target first (prod always is).
      --no-static           Don't regenerate the target's static site.
      --confirm PHRASE      Confirm without being asked.
  -h, --help                Show this help.

You're asked to confirm before anything changes. Syncing up (e.g. dev to
staging) or into prod asks for a longer phrase and says why it's risky.
EOF
}

die() {
  echo "ERROR: $*" >&2
  exit 1
}

## Inputs. Environment variables set them in downsync.yml; flags set them here.
SOURCE_SPACE="${SOURCE_SPACE:-prod}"
TARGET_SPACE="${TARGET_SPACE:-}"
SYNC_DATABASE="${SYNC_DATABASE:-true}"
SYNC_FILES="${SYNC_FILES:-true}"
USE_LATEST_BACKUP="${USE_LATEST_BACKUP:-false}"
BACKUP_TARGET_FIRST="${BACKUP_TARGET_FIRST:-true}"
REGENERATE_STATIC="${REGENERATE_STATIC:-true}"
DATABASE_FILE_OVERRIDE="${DATABASE_FILE_OVERRIDE:-}"
STORAGE_FILE_OVERRIDE="${STORAGE_FILE_OVERRIDE:-}"
CONFIRM="${CONFIRM:-}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    -s|--source|-t|--target|--database-file|--files-file|--confirm)
      [[ -n "${2:-}" ]] || die "$1 needs a value."
      case "$1" in
        -s|--source) SOURCE_SPACE="$2" ;;
        -t|--target) TARGET_SPACE="$2" ;;
        --database-file) DATABASE_FILE_OVERRIDE="$2" ;;
        --files-file) STORAGE_FILE_OVERRIDE="$2" ;;
        --confirm) CONFIRM="$2" ;;
      esac
      shift 2
      ;;
    --database-only) SYNC_FILES=false; shift ;;
    --files-only) SYNC_DATABASE=false; shift ;;
    --use-latest-backup) USE_LATEST_BACKUP=true; shift ;;
    --no-target-backup) BACKUP_TARGET_FIRST=false; shift ;;
    --no-static) REGENERATE_STATIC=false; shift ;;
    -h|--help) usage; exit 0 ;;
    *) usage >&2; echo >&2; die "Unknown option: $1" ;;
  esac
done

[[ -n "${TARGET_SPACE}" ]] || { usage >&2; echo >&2; die "--target is required."; }

## The prefix of every Cloud.gov app and service name. downsync.yml passes it
## from a secret; elsewhere it comes from the Terraform that names them.
if [[ -z "${PROJECT}" ]]; then
  PROJECT="$(sed -n -E 's/^[[:space:]]*project[[:space:]]*=[[:space:]]*"([^"]+)".*/\1/p' \
    "${REPO_ROOT}/terraform/infra/locals.tf" | head -1)"
fi
[[ -n "${PROJECT}" ]] || die "Couldn't work out the project name; set PROJECT."
## The bastion's app key in terraform/infra/locals.tf.
DATABASE_BACKUP_BASTION_NAME="${DATABASE_BACKUP_BASTION_NAME:-database-backup-bastion}"
export PROJECT DATABASE_BACKUP_BASTION_NAME

## Back up the source now, unless an existing backup was chosen.
FRESH_SOURCE_DATABASE=false
FRESH_SOURCE_FILES=false
if [[ "${USE_LATEST_BACKUP}" != "true" ]]; then
  [[ "${SYNC_DATABASE}" == "true" && -z "${DATABASE_FILE_OVERRIDE}" ]] && FRESH_SOURCE_DATABASE=true
  [[ "${SYNC_FILES}" == "true" && -z "${STORAGE_FILE_OVERRIDE}" ]] && FRESH_SOURCE_FILES=true
fi

## Start a step: a collapsible section in GitHub's log (a heading elsewhere),
## and a fresh directory to work in. The previous step's directory goes: the
## scripts leave dumps and archives behind, several GB of them, and two backups
## in one run would otherwise collide on the same file names.
CURRENT_STEP=""
STEP_NUMBER=0
section() {
  end_section
  CURRENT_STEP="$*"
  if [[ "${GITHUB_ACTIONS}" == "true" ]]; then
    echo "::group::$*"
    IN_GROUP=1
  else
    echo
    echo "==> $*"
  fi
  cd "${WORK_DIR}"
  if [[ -n "${STEP_DIR:-}" ]]; then
    rm -rf "${STEP_DIR}"
  fi
  STEP_NUMBER=$((STEP_NUMBER + 1))
  STEP_DIR="${WORK_DIR}/step-${STEP_NUMBER}"
  mkdir "${STEP_DIR}"
  cd "${STEP_DIR}"
}
end_section() {
  if [[ -n "${IN_GROUP:-}" ]]; then
    echo "::endgroup::"
    IN_GROUP=""
  fi
}

check_tools() {
  local tool missing=()
  local tools=(cf jq aws tar gzip)
  if [[ "${SYNC_DATABASE}" == "true" ]]; then
    tools+=(mysql mysqldump)
  fi
  for tool in "${tools[@]}"; do
    command -v "${tool}" >/dev/null 2>&1 || missing+=("${tool}")
  done
  if (( ${#missing[@]} )); then
    die "Not installed: ${missing[*]}. See Prerequisites in docs/devops.md."
  fi
  [[ "$(cf --version)" == *"cf version 8."* ]] || die "This needs cf version 8, not: $(cf --version)"
  cf target >/dev/null 2>&1 || die "Not logged in to Cloud.gov. Run: cf login -a api.fr.cloud.gov --sso"
  if [[ "${SYNC_DATABASE}" == "true" ]] && ! cf plugins 2>/dev/null | grep -q connect-to-service; then
    die "The cf-service-connect plugin isn't installed. See Prerequisites in docs/devops.md."
  fi
}

describe_copy() {
  local fresh=$1 override=$2
  if [[ -n "${override}" ]]; then
    echo "${SOURCE_SPACE}'s backup ${override}"
  elif [[ "${fresh}" == "true" ]]; then
    echo "${SOURCE_SPACE}'s, backed up now"
  else
    echo "${SOURCE_SPACE}'s latest backup"
  fi
}

print_plan() {
  echo "Downsync ${SOURCE_SPACE} -> ${TARGET_SPACE}"
  if [[ "${SYNC_DATABASE}" == "true" ]]; then
    echo "  Database:      replaced with $(describe_copy "${FRESH_SOURCE_DATABASE}" "${DATABASE_FILE_OVERRIDE}")"
  fi
  if [[ "${SYNC_FILES}" == "true" ]]; then
    echo "  Public files:  replaced with $(describe_copy "${FRESH_SOURCE_FILES}" "${STORAGE_FILE_OVERRIDE}")"
  fi
  echo "  Back up ${TARGET_SPACE} first: ${BACKUP_TARGET_FIRST}"
  echo "  Afterwards:    drush deploy on ${TARGET_SPACE}$([[ "${REGENERATE_STATIC}" == "true" ]] && echo ", then regenerate its static site")"
  echo
}

## downsync.yml runs the preflight as its own step, so a wrong phrase fails
## before anything is installed, and passes its result in. Everywhere else it
## runs here, and asks for the phrase in the terminal.
run_preflight() {
  if [[ "${GITHUB_ACTIONS}" == "true" && "${PREFLIGHT_DONE}" == "true" ]]; then
    return 0
  fi
  if [[ -z "${INSTALL_DRUPAL_SPACES+set}" ]]; then
    echo "Note: this can't see the INSTALL_DRUPAL_SPACES GitHub variable. If it lists ${TARGET_SPACE}, ${TARGET_SPACE}'s next deploy will reinstall it and throw this copy away."
    echo
  fi
  local output
  output="$(mktemp)"
  GITHUB_OUTPUT="${output}" SOURCE_SPACE="${SOURCE_SPACE}" TARGET_SPACE="${TARGET_SPACE}" \
    CONFIRM="${CONFIRM}" SYNC_DATABASE="${SYNC_DATABASE}" SYNC_FILES="${SYNC_FILES}" \
    BACKUP_TARGET_FIRST="${BACKUP_TARGET_FIRST}" REGENERATE_STATIC="${REGENERATE_STATIC}" \
    INSTALL_DRUPAL_SPACES="${INSTALL_DRUPAL_SPACES}" \
    "${PIPELINE}/downsync-preflight.sh" || { rm -f "${output}"; exit 1; }
  BACKUP_TARGET_FIRST="$(sed -n 's/^backup_target=//p' "${output}")"
  rm -f "${output}"
}

bastion_app() {
  echo "${PROJECT}-${DATABASE_BACKUP_BASTION_NAME}-$1"
}

target_space() {
  cf target -s "$1" >/dev/null || die "Couldn't target the '$1' space. Check that you have access to it."
}

STARTED_BASTIONS=()
start_bastion() {
  local app
  app="$(bastion_app "$1")"
  target_space "$1"
  STARTED_BASTIONS+=("$1")
  cf start "${app}" >/dev/null || die "Couldn't start ${app}."
  "${PIPELINE}/cloud-gov-wait-for-app-start.sh" "${app}"
}

## Run a pipeline script against a space, with the shell options GitHub gives
## the workflows that source these scripts. Extra arguments are VAR=value.
run_in_space() {
  local space=$1 script=$2
  shift 2
  target_space "${space}"
  env CF_SPACE="${space}" "$@" bash -eo pipefail "${PIPELINE}/${script}"
}

## Stop a process and everything it started, children first.
kill_tree() {
  local child
  for child in $(pgrep -P "$1" 2>/dev/null || true); do
    kill_tree "${child}"
  done
  kill "$1" 2>/dev/null || true
}

stop_logs() {
  if [[ -n "${LOGS_PID:-}" ]]; then
    kill_tree "${LOGS_PID}"
    LOGS_PID=""
  fi
}

## Run the target's upkeep task (scripts/upkeep), which regenerates the static
## site, and show its log lines while it runs.
regenerate_static() {
  local app="${PROJECT}-drupal-${TARGET_SPACE}"
  local task="${app}-upkeep"
  local status=0
  target_space "${TARGET_SPACE}"
  ( cf logs "${app}" | grep --line-buffered "${task}" ) &
  LOGS_PID=$!
  cf run-task "${app}" --command "/home/vcap/app/scripts/upkeep" --wait -m 1G -k 4G --name "${task}" || status=$?
  stop_logs
  [[ ${status} -eq 0 ]] || die "The upkeep task failed. Its log: cf logs ${app} --recent"
}

cleanup() {
  local status=$?
  local space
  end_section
  stop_logs
  if (( ${#STARTED_BASTIONS[@]} )); then
    echo
    echo "==> Stopping bastions"
    for space in "${STARTED_BASTIONS[@]}"; do
      cf target -s "${space}" >/dev/null 2>&1 && cf stop "$(bastion_app "${space}")" >/dev/null 2>&1 || true
    done
  fi
  if [[ -n "${ORIGINAL_SPACE:-}" ]]; then
    cf target -s "${ORIGINAL_SPACE}" >/dev/null 2>&1 || true
  fi
  cd /
  if [[ -n "${WORK_DIR:-}" && -d "${WORK_DIR}" ]]; then
    rm -rf "${WORK_DIR}"
  fi
  if [[ ${status} -ne 0 && -n "${CURRENT_STEP}" ]]; then
    echo >&2
    echo "Downsync failed while: ${CURRENT_STEP}." >&2
    echo "See Troubleshooting in docs/runbooks/github/downsync.yml.MD." >&2
  fi
  exit ${status}
}

check_tools
print_plan
run_preflight

trap cleanup EXIT
trap 'exit 130' INT TERM

ORIGINAL_SPACE="$(cf target | awk '/^space:/ {print $2}')"

## Every download and archive lands under here, and it all goes when this
## exits. On a computer it can hold several GB of production data.
tmp_root="${TMPDIR:-/tmp}"
WORK_DIR="$(mktemp -d "${tmp_root%/}/downsync.XXXXXX")"

## Keep macOS tar from adding ._ metadata files to the files archives.
export COPYFILE_DISABLE=1

## One timestamp names every backup this run takes.
TIMESTAMP="$(date -u +%Y-%m-%dT%H-%M-%SZ)"

if [[ "${FRESH_SOURCE_DATABASE}" == "true" ]]; then
  section "Starting ${SOURCE_SPACE}'s bastion"
  start_bastion "${SOURCE_SPACE}"
fi
if [[ "${SYNC_DATABASE}" == "true" ]]; then
  section "Starting ${TARGET_SPACE}'s bastion"
  start_bastion "${TARGET_SPACE}"
fi

if [[ "${FRESH_SOURCE_DATABASE}" == "true" ]]; then
  section "Backing up ${SOURCE_SPACE}'s database"
  run_in_space "${SOURCE_SPACE}" database-backup.sh TIMESTAMP="${TIMESTAMP}"
fi
if [[ "${FRESH_SOURCE_FILES}" == "true" ]]; then
  section "Backing up ${SOURCE_SPACE}'s files"
  run_in_space "${SOURCE_SPACE}" files-backup.sh FILES_BACKUP_TYPE=storage TIMESTAMP="${TIMESTAMP}"
fi

if [[ "${BACKUP_TARGET_FIRST}" == "true" && "${SYNC_DATABASE}" == "true" ]]; then
  section "Backing up ${TARGET_SPACE}'s database"
  run_in_space "${TARGET_SPACE}" database-backup.sh TIMESTAMP="${TIMESTAMP}"
fi
if [[ "${BACKUP_TARGET_FIRST}" == "true" && "${SYNC_FILES}" == "true" ]]; then
  section "Backing up ${TARGET_SPACE}'s files"
  run_in_space "${TARGET_SPACE}" files-backup.sh FILES_BACKUP_TYPE=storage TIMESTAMP="${TIMESTAMP}"
fi

if [[ "${SYNC_FILES}" == "true" ]]; then
  section "Copying ${SOURCE_SPACE}'s public files to ${TARGET_SPACE}"
  run_in_space "${TARGET_SPACE}" files-restore.sh FILES_BACKUP_TYPE=storage \
    BACKUP_SPACE="${SOURCE_SPACE}" PUBLIC_FILES_ONLY=1 S3_FILE_PATH="${STORAGE_FILE_OVERRIDE}"
fi

if [[ "${SYNC_DATABASE}" == "true" ]]; then
  section "Copying ${SOURCE_SPACE}'s database to ${TARGET_SPACE}"
  run_in_space "${TARGET_SPACE}" s3-backup-download.sh \
    BACKUP_SPACE="${SOURCE_SPACE}" S3_FILE_PATH="${DATABASE_FILE_OVERRIDE}"
  run_in_space "${TARGET_SPACE}" database-restore.sh
fi

section "Updating ${TARGET_SPACE} for its code (drush deploy)"
run_in_space "${TARGET_SPACE}" cloud-gov-post-sync.sh

if [[ "${REGENERATE_STATIC}" == "true" ]]; then
  section "Regenerating ${TARGET_SPACE}'s static site"
  regenerate_static
fi

end_section
CURRENT_STEP=""
echo
echo "Downsync ${SOURCE_SPACE} -> ${TARGET_SPACE} finished."
