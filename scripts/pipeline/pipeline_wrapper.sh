#!/bin/bash

if [ -z "${1}" ]; then
  echo "The name of the script to run must be the first argument"
  exit 1
fi

if [ -z "${CF_SPACE}" ] || [ -z "${PROJECT}" ]; then
  if [ -z "${CF_SPACE}" ]; then
    echo "CF_SPACE must be set for " $(basename "$0")
  fi

  if [ -z "${PROJECT}" ]; then
    echo "PROJECT must be set for " $(basename "$0")
  fi
  exit 1
fi

APP="${PROJECT}-drupal-${CF_SPACE}"
TASK_NAME="${APP}-${1}"

# Don't start the task while another copy of it is still running. Automated
# runs skip straight away (MAX_WAIT_MINUTES=0); manual ones like deploys wait
# up to MAX_WAIT_MINUTES for it to finish, then skip.
MAX_WAIT_MINUTES="${MAX_WAIT_MINUTES:-0}"
APP_GUID=$(cf app --guid "${APP}") || exit 1
DEADLINE=$(( $(date +%s) + MAX_WAIT_MINUTES * 60 ))
while true; do
  TASKS_JSON=$(cf curl --fail "/v3/apps/${APP_GUID}/tasks?names=${TASK_NAME}&states=PENDING,RUNNING,CANCELING") || {
    echo "Could not check whether ${TASK_NAME} is already running"
    exit 1
  }
  STARTED_AT=$(echo "${TASKS_JSON}" | jq -r '[.resources[].created_at] | join(", ")')
  if [ -z "${STARTED_AT}" ]; then
    break
  fi

  if [ "$(date +%s)" -ge "${DEADLINE}" ]; then
    echo "::warning::${TASK_NAME} is already running (started ${STARTED_AT}), skipping this run."
    exit 0
  fi

  echo "${TASK_NAME} is already running (started ${STARTED_AT}), checking again in 30s..."
  sleep 30
done

echo "${CF_SPACE} is running ${1} now..."
cf run-task "${APP}" --command "/home/vcap/app/scripts/${1}" --wait -m 1G -k 4G --name "${TASK_NAME}" &
RUN_TASK_PID=$!

cf logs "${APP}" | grep "${TASK_NAME}" &
sleep 1
CF_LOGS_PID=$(pgrep -f "cf logs")

# Wait till the task is complete.
wait "${RUN_TASK_PID}"

# Now stop cf logs from running.
kill "${CF_LOGS_PID}"
