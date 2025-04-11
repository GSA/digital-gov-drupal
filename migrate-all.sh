#!/bin/bash

set -xe

if [ -n "$VCAP_APPLICATION" ] && [ "$environment" != "dev" ]; then
  echo "Migrations should only run locally or in dev not in {$environment}".
  exit 1;
fi

echo "You are about to migrate all content, this will delete existing content in this instance."
read -p "Are you sure you want to proceed (Y/y to proceed)? " CONFIRM

if [ "$CONFIRM" != "Y" ] && [ "$CONFIRM" != "y" ]; then
  echo "Migrations skipped."
  exit 1;
fi

echo "OK";

# Ensure in the app directory.
cd "$(dirname "$0")"

DRUSH_BIN="./drush.sh"
[ -n "$VCAP_APPLICATION" ] && DRUSH_BIN="drush"

# Runs all the migration steps in the expected order

# 1. Remove content created by default content that will be imported by the
# scripts.
${DRUSH_BIN} rcbm

# 2. Build the feed for s3files that are directly linked in markdown,
#    not with the asset short code
${DRUSH_BIN} digitalgov:s3feed > web/sites/default/files/s3files.json

cat web/sites/default/files/s3files.json
if [ -n "$VCAP_APPLICATION" ]; then
  drush s3fs-rc
  drush s3fs-cl -y --scheme=public --condition=newer
fi

# 3. Run all the migrations.
${DRUSH_BIN} cr
# Throws notices that kill the script.
${DRUSH_BIN} migrate:rollback --tag="digitalgov"
${DRUSH_BIN} migrate:rollback --tag="digitalgov-guidenav"
${DRUSH_BIN} migrate:import --tag="digitalgov"
${DRUSH_BIN} migrate:import --tag="digitalgov-guidenav"

if [ -n "$VCAP_APPLICATION" ]; then
  drush s3fs-rc
  drush s3fs-cl -y --scheme=public --condition=newer
fi

# 4. Clean up migrated content (shortcodes, media links, emoji).
${DRUSH_BIN} digitalgov:update-nodes
${DRUSH_BIN} digitalgov:update-paragraphs

rm ./web/sites/default/files/s3files.json

echo "Run migrate-messages.sh to check for errors."
