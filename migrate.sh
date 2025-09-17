#!/usr/bin/env bash

cd "$(dirname "$0")" || exit

if [ -z "$1" ]; then
  ./drush.sh migrate:status
  echo "Please provide a migration ID to run, any additional values will be passed to the the migration import."
  exit 1
fi

if [ -n "$VCAP_APPLICATION" ] && [ "$environment" != "dev" ]; then
  echo "Migrations should only run locally or in dev not in {$environment}".
  exit 1;
fi

echo "You are about to migrate content, this will delete existing content in this instance."
read -p "Are you sure you want to proceed (Y/y to proceed)? " CONFIRM

if [ "$CONFIRM" != "Y" ] && [ "$CONFIRM" != "y" ]; then
  echo "Migrations skipped."
  exit 1;
fi

migrate_id="$1"      # Store the first argument
shift                # Shift arguments to the left, removing $1
remaining_args="$*"  # Capture all remaining arguments as a single string

./drush.sh cr && ./drush.sh migrate:reset-status "$migrate_id" && ./drush.sh migrate:rollback "$migrate_id" && ./drush.sh migrate:import "$migrate_id" "$remaining_args"
