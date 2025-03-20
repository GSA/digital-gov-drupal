#!/bin/bash

set -xe

DRUSH_BIN="./drush.sh"
[ -n "$VCAP_APPLICATION" ] && DRUSH_BIN="drush"

# Runs all the migration steps in the expected order

# 1. Remove content created by default content that will be imported by the
# scripts.
${DRUSH_BIN} rcbm

# 2. Build the feed for s3files that are directly linked in markdown,
#    not with the asset short code
${DRUSH_BIN} digitalgov:s3feed > web/sites/default/files/s3files.json

# 3. Run all the migrations.
${DRUSH_BIN} cr
${DRUSH_BIN} migrate:rollback --tag="digitalgov"
${DRUSH_BIN} migrate:import --tag="digitalgov"

# 4. Clean up migrated content (shortcodes, media links, emoji).
${DRUSH_BIN} digitalgov:update-nodes
${DRUSH_BIN} digitalgov:update-paragraphs

#rm ./web/sites/default/files/s3files.json
