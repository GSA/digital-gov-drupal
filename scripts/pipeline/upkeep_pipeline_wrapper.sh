#!/bin/bash

if [ -z "${CF_SPACE}" ] || [ -z "${PROJECT}" ]; then
  if [ -z "${CF_SPACE}" ]; then
    echo "CF_SPACE must be set for " $(basename "$0")
  fi

  if [ -z "${PROJECT}" ]; then
    echo "PROJECT must be set for " $(basename "$0")
  fi
  exit 1
fi


echo "${CF_SPACE} is building the static site now..."
APP="${PROJECT}-drupal-${CF_SPACE}"
TASK_NAME="${APP}-upkeep"

cf run-task "${APP}" --command "/home/vcap/app/scripts/upkeep" --wait -m 1G -k 4G --name "${TASK_NAME}" &
RUN_TASK_PID=$!

cf logs "${APP}" | grep "${TASK_NAME}" &
sleep 1
CF_LOGS_PID=$(pgrep -f "cf logs")

# Wait till the task is complete.
wait "${RUN_TASK_PID}"

# Now stop cf logs from running.
kill "${CF_LOGS_PID}"
