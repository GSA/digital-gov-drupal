#!/bin/bash

set -e

# Wait until drupal app is running
until cf app "${PROJECT}-drupal-${CF_SPACE}" | grep running
do
  sleep 1
done

# Enable SSH if in prod
if [[ ${CF_SPACE} = "prod" ]]; then
  cf allow-space-ssh "${CF_SPACE}"
  cf enable-ssh "${PROJECT}-drupal-${CF_SPACE}"
  cf restart --strategy rolling "${PROJECT}-drupal-${CF_SPACE}"

  # Wait until drupal app is running
  until cf app "${PROJECT}-drupal-${CF_SPACE}" | grep running
  do
    sleep 1
  done

fi

# Determine if re-installing Drupal or just updating.

# Default to 'update'
DRUPAL_UPDATE_OR_INSTALL="update"

# Convert INSTALL_DRUPAL_SPACES into an array and check if CF_SPACE is in it
IFS=',' read -ra SPACES <<< "$INSTALL_DRUPAL_SPACES"
for space in "${SPACES[@]}"; do
    if [[ "$CF_SPACE" == "$space" ]]; then
        DRUPAL_UPDATE_OR_INSTALL="install"
        break
    fi
done

echo "Running post deploy steps..."
cf ssh "${PROJECT}-drupal-${CF_SPACE}" --command "PATH=/home/vcap/deps/1/bin:/home/vcap/deps/0/bin:/usr/local/bin:/usr/bin:/bin:/home/vcap/app/php/bin:/home/vcap/app/php/sbin:/home/vcap/app/php/bin:/home/vcap/app/vendor/drush/drush DRUPAL_UPDATE_OR_INSTALL=${DRUPAL_UPDATE_OR_INSTALL} app/scripts/post-deploy && echo 'Successfully completed post deploy!' || echo 'Failed to complete post deploy!'"

## Clean up.
if [[ ${CF_SPACE} = "prod" ]]; then
  cf disallow-space-ssh "${CF_SPACE}"
  cf disable-ssh "${PROJECT}-drupal-${CF_SPACE}"
fi
