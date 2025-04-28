#!/usr/bin/env bash

set -e

./orch/show_file.sh $0

# Normally, XDEBUG_MODE=debug,develop but develop breaks the Drupal installation.
# https://www.drupal.org/project/drupal/issues/3405976.
if [ -n "$XDEBUG_MODE" ]; then
  export XDEBUG_MODE=debug
fi

# Drupal must be installed to update it.
if [ -n "$(drush status --fields=bootstrap)" ]; then
  echo 'Updating Drupal'
  drush state:set system.maintenance_mode 1 -y
  echo "Ensure site is up to date from code"
  drush deploy
  # Required if config splits is enabled.
  if [ "$(drush pm-list --type=module --status=enabled --no-core | grep 'config_split')" ] && [ -n "$(ls $(drush php:eval "echo realpath(Drupal\Core\Site\Settings::get('config_sync_directory'));")/*.yml 2>/dev/null)" ]; then
    drush cr
    drush cim -y
  fi
  drush state:set system.maintenance_mode 0 -y
  echo "Finished updating Drupal!"
else
  echo "Drupal is not installed, cannot update. Installing instead"
  ./orch/deploy_install.sh
fi

./orch/show_file.sh $0 end
