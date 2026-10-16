#!/bin/bash

## After a sync from prod (sync-from-prod.yml), bring ${CF_SPACE} up to date
## with its own code -- update hooks, config import, cache rebuild -- then
## rebuild s3fs's file metadata from the bucket, since the copied s3fs_file
## table describes prod's. Unlike cloud-gov-post-deploy.sh, a failure here
## fails the step.

set -e

app="${PROJECT}-drupal-${CF_SPACE}"

## The PATH cloud-gov-post-deploy.sh gives its remote command.
remote_path="/home/vcap/deps/1/bin:/home/vcap/deps/0/bin:/usr/local/bin:/usr/bin:/bin:/home/vcap/app/php/bin:/home/vcap/app/php/sbin:/home/vcap/app/vendor/drush/drush"

## The leading cache rebuild clears what the shared Valkey cache still holds
## from the old database; like deploy_install.sh, carry on if it fails.
echo "Running post sync steps..."
cf ssh "${app}" --command "export PATH=${remote_path} DRUPAL_UPDATE_OR_INSTALL=update && cd /home/vcap/app && (drush cr || :) && ./orch/deploy.sh && drush s3fs-rc && drush cr"
echo "Successfully completed post sync!"
