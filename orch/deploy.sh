#!/usr/bin/env bash

set -e

./orch/show_file.sh $0

echo "Relevant environment variables and their values:"
echo ""
echo "DRUPAL_UPDATE_OR_INSTALL: ${DRUPAL_UPDATE_OR_INSTALL}"

set -x
if [ "${DRUPAL_UPDATE_OR_INSTALL}" = 'update' ]; then
    ./orch/deploy_update.sh
elif [ "${DRUPAL_UPDATE_OR_INSTALL}" = 'install' ]; then
    ./orch/deploy_install.sh
else
    echo "Env variable DRUPAL_UPDATE_OR_INSTALL must be set when deploy.sh is run. 'update' to update (runs updates and installs config, installs if not installed only) Drupal or 'install' to install Drupal fresh every time."
    exit 1
fi

./orch/show_file.sh $0 end
