#!/bin/bash

set -e

# Wait until drupal app is running
until cf app "${PROJECT}-drupal-${CF_SPACE}" | grep running
do
  sleep 1
done

# Enable SSH if in prod
if [[ ${CF_SPACE} = "prod" ]]; then
  cf enable-ssh "${PROJECT}-drupal-${CF_SPACE}"
  cf restart --strategy rolling "${PROJECT}-drupal-${CF_SPACE}"

  # Wait until drupal app is running
  until cf app "${PROJECT}-drupal-${CF_SPACE}" | grep running
  do
    sleep 1
  done

fi

echo "Running post deploy steps..."
cf ssh "${PROJECT}-drupal-${CF_SPACE}" --command "PATH=/home/vcap/deps/1/bin:/home/vcap/deps/0/bin:/usr/local/bin:/usr/bin:/bin:/home/vcap/app/php/bin:/home/vcap/app/php/sbin:/home/vcap/app/php/bin:/home/vcap/app/vendor/drush/drush app/scripts/post-deploy >/dev/null 2>&1 && echo 'Successfully completed post deploy!' || echo 'Failed to complete post deploy!'"

## Clean up.
if [[ ${CF_SPACE} = "prod" ]]; then
  cf disable-ssh "${PROJECT}-drupal-${CF_SPACE}"
fi
