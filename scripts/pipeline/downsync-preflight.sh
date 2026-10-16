#!/bin/bash

## Checks a downsync before anything is touched: that both spaces are valid
## and different, and that the person running it has confirmed with the phrase
## this direction requires. A normal downsync asks for the target's name.
## Syncing up a tier, or into prod, asks for its own phrase, and is flagged in
## the log (and, in GitHub Actions, the run's annotations and summary) even
## once confirmed.
##
## Run by scripts/downsync.sh, and as its own step in downsync.yml so a wrong
## phrase fails before anything is installed.
##
## Required environment variables:
##   SOURCE_SPACE, TARGET_SPACE   The spaces to copy from and to.
##
## The confirmation comes from CONFIRM (the workflow input, or --confirm). If
## it is empty and this is a terminal, the phrase is asked for after the
## warnings are shown.
##
## Optional environment variables (workflow inputs, "true" or "false"):
##   SYNC_DATABASE, SYNC_FILES, BACKUP_TARGET_FIRST, REGENERATE_STATIC
##   INSTALL_DRUPAL_SPACES        The repository variable of the same name.
##
## Writes backup_target=true|false to $GITHUB_OUTPUT. It is always true when
## the target is prod.

set -eo pipefail

## Lowest tier first. Copying toward the end of this list is an upward sync.
SPACES=(dev staging prod)
PRODUCTION_SPACE="prod"

summary() {
  if [[ -n "${GITHUB_STEP_SUMMARY}" ]]; then
    echo "$*" >> "${GITHUB_STEP_SUMMARY}"
  fi
}

## GitHub shows these on the run's page; elsewhere they're plain log lines.
annotate() {
  if [[ "${GITHUB_ACTIONS}" == "true" ]]; then
    echo "::$1 title=$2::$3"
  elif [[ "$1" == "error" ]]; then
    echo "ERROR: $3" >&2
  fi
}

fail() {
  annotate error "Downsync stopped" "$*"
  summary "**Stopped:** $*"
  exit 1
}

## Prints a space's position in SPACES; fails for an unknown space.
tier() {
  local i
  for i in "${!SPACES[@]}"; do
    if [[ "${SPACES[$i]}" == "$1" ]]; then
      echo "${i}"
      return 0
    fi
  done
  return 1
}

for var in SOURCE_SPACE TARGET_SPACE; do
  tier "${!var}" >/dev/null || fail "${var} must be one of ${SPACES[*]}, not '${!var}'."
done
if [[ "${SOURCE_SPACE}" == "${TARGET_SPACE}" ]]; then
  fail "Source and target are both '${TARGET_SPACE}'."
fi
if [[ "${SYNC_DATABASE}" != "true" && "${SYNC_FILES}" != "true" ]]; then
  fail "Nothing to do: sync_database and sync_files are both off."
fi

## A space listed here is reinstalled from default content on its next
## deploy, which would throw away everything this workflow copies in.
IFS=',' read -ra install_spaces <<< "${INSTALL_DRUPAL_SPACES}"
for space in "${install_spaces[@]}"; do
  if [[ "${space}" == "${TARGET_SPACE}" ]]; then
    fail "'${TARGET_SPACE}' is in INSTALL_DRUPAL_SPACES, so its next deploy would reinstall it. Remove it from that variable first."
  fi
done

warnings=()
backup_target="${BACKUP_TARGET_FIRST:-false}"

if [[ "${TARGET_SPACE}" == "${PRODUCTION_SPACE}" ]]; then
  direction="into production"
  phrase="overwrite ${PRODUCTION_SPACE} with ${SOURCE_SPACE}"
  warnings+=(
    "THIS RUN OVERWRITES PRODUCTION. ${PRODUCTION_SPACE}'s database and public files will be replaced with ${SOURCE_SPACE}'s, and anything created or changed in ${PRODUCTION_SPACE} since then will be lost."
    "Downsync is the wrong tool for restoring ${PRODUCTION_SPACE}. To roll it back, run Database Restore and Files Restore from main instead. Only continue if you have a reason they can't do the job."
    "${SOURCE_SPACE} usually runs newer code than ${PRODUCTION_SPACE}. Its database may already have update hooks and schema changes that ${PRODUCTION_SPACE}'s code doesn't expect, and drush deploy can't undo them."
  )
  if [[ "${REGENERATE_STATIC}" == "true" ]]; then
    warnings+=("regenerate_static is on, so ${SOURCE_SPACE}'s content will be published on the public site.")
  fi
  if [[ "${backup_target}" != "true" ]]; then
    echo "backup_target_first is off, but ${PRODUCTION_SPACE} is always backed up before it is overwritten."
    backup_target="true"
  fi
elif [[ $(tier "${TARGET_SPACE}") -gt $(tier "${SOURCE_SPACE}") ]]; then
  direction="up"
  phrase="sync ${SOURCE_SPACE} up to ${TARGET_SPACE}"
  downward=""
  for ((i = ${#SPACES[@]} - 1; i >= 0; i--)); do
    downward+="${downward:+ -> }${SPACES[$i]}"
  done
  warnings+=(
    "This is an upward sync. ${SOURCE_SPACE} usually runs newer code than ${TARGET_SPACE}. Its database may already have update hooks and schema changes that ${TARGET_SPACE}'s code doesn't expect, and drush deploy can't undo them, so ${TARGET_SPACE} may stay broken until its branch catches up."
    "The usual direction is down: ${downward}."
  )
else
  direction="down"
  phrase="${TARGET_SPACE}"
fi

summary "## Downsync ${SOURCE_SPACE} to ${TARGET_SPACE} (${direction})"
summary ""

if (( ${#warnings[@]} )); then
  echo "################################################################"
  echo "##  WARNING: ${SOURCE_SPACE} -> ${TARGET_SPACE} (${direction})"
  echo "################################################################"
  for warning in "${warnings[@]}"; do
    echo "## ${warning}"
    annotate warning "Downsync ${direction}" "${warning}"
    summary "- **Warning:** ${warning}"
  done
  echo "################################################################"
  summary ""
fi

confirm="${CONFIRM}"
if [[ -n "${confirm}" ]]; then
  if [[ "${GITHUB_ACTIONS}" == "true" ]]; then
    mismatch="confirm doesn't match. To go ahead, run the workflow again with confirm set to exactly: ${phrase}"
  else
    mismatch="--confirm doesn't match. To go ahead, use --confirm '${phrase}', or leave it out to be asked."
  fi
elif [[ -t 0 && "${GITHUB_ACTIONS}" != "true" ]]; then
  if [[ "${direction}" == "down" ]]; then
    echo "This overwrites ${TARGET_SPACE}'s data with ${SOURCE_SPACE}'s."
  fi
  ## Ctrl-D ends the read without a value, which is a mismatch like any other.
  read -r -p "Type '${phrase}' to continue: " confirm || echo
  mismatch="That doesn't match '${phrase}'. Nothing was changed."
else
  fail "No confirmation given. It needs to be: ${phrase}"
fi

## Leading and trailing spaces are forgiven; everything else must match.
confirm="${confirm#"${confirm%%[![:space:]]*}"}"
confirm="${confirm%"${confirm##*[![:space:]]}"}"
if [[ "${confirm}" != "${phrase}" ]]; then
  fail "${mismatch}"
fi

echo "Confirmed: overwriting ${TARGET_SPACE} with ${SOURCE_SPACE}'s data (${direction})."
summary "Confirmed with \`${phrase}\`. Target backed up first: ${backup_target}."

if [[ -n "${GITHUB_OUTPUT}" ]]; then
  echo "backup_target=${backup_target}" >> "${GITHUB_OUTPUT}"
fi
