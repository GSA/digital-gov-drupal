#!/bin/bash

## After downsync.yml copies another space's data into ${CF_SPACE}, bring it up
## to date with its own code -- update hooks, config import, cache rebuild --
## then rebuild s3fs's file metadata from the bucket, since the copied
## s3fs_file table describes the source's. Unlike cloud-gov-post-deploy.sh, a
## failure here fails the step.

set -e

app="${PROJECT}-drupal-${CF_SPACE}"

## The PATH cloud-gov-post-deploy.sh gives its remote command.
remote_path="/home/vcap/deps/1/bin:/home/vcap/deps/0/bin:/usr/local/bin:/usr/bin:/bin:/home/vcap/app/php/bin:/home/vcap/app/php/sbin:/home/vcap/app/vendor/drush/drush"

## Prod's space keeps SSH off. Open it as cloud-gov-post-deploy.sh does (SSH on
## the app takes effect after a restart), and close it however this exits.
if [[ ${CF_SPACE} = "prod" ]]; then
  trap 'cf disallow-space-ssh "${CF_SPACE}"; cf disable-ssh "${app}"' EXIT
  cf allow-space-ssh "${CF_SPACE}"
  cf enable-ssh "${app}"
  cf restart --strategy rolling "${app}"

  # Wait until drupal app is running
  until cf app "${app}" | grep running
  do
    sleep 1
  done
fi

## The leading cache rebuild clears what the shared Valkey cache still holds
## from the old database; like deploy_install.sh, carry on if it fails.
echo "Running post sync steps..."
cf ssh "${app}" --command "export PATH=${remote_path} DRUPAL_UPDATE_OR_INSTALL=update && cd /home/vcap/app && (drush cr || :) && ./orch/deploy.sh && drush s3fs-rc && drush cr"
echo "Successfully completed post sync!"
