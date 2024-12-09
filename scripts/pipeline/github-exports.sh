#!/bin/bash

#BRANCH=$(echo $GITHUB_REF | cut -d'/' -f 3)
BRANCH=develop
COMPOSER_DEV=1
GSA_AUTH_KEY=${{ secrets.GSA_AUTH_DEVELOPMENT_KEY }}
case ${BRANCH} in
  develop)
    CF_SPACE="dev"
    DRUPAL_MEMORY=${{ vars.DEVELOP_CMS_MEMORY }}
    DRUPAL_INSTANCES=${{ vars.DEVELOP_INSTANCES }}
    ;;
  main)
    CF_SPACE="prod"
    COMPOSER_DEV=0
    DRUPAL_MEMORY=${{ vars.MAIN_CMS_MEMORY }}
    DRUPAL_INSTANCES=${{ vars.MAIN_INSTANCES }}
    GSA_AUTH_KEY=${{ secrets.GSA_AUTH_PRODUCTION_KEY }}
    ;;
  stage)
    CF_SPACE="staging"
    COMPOSER_DEV=0
    DRUPAL_MEMORY=${{ vars.STAGE_CMS_MEMORY }}
    DRUPAL_INSTANCES=${{ vars.STAGE_INSTANCES }}
    ;;
esac

echo "APP_NAME=drupal" | tee -a $GITHUB_ENV
echo "BRANCH=${BRANCH}" | tee -a $GITHUB_ENV
echo "BUILDPACK_PORT=${{ vars.BUILDPACK_PORT }}" | tee -a $GITHUB_ENV
echo "CF_SPACE=${CF_SPACE}" | tee -a $GITHUB_ENV
echo "COMPOSER_DEV=${COMPOSER_DEV}" | tee -a $GITHUB_ENV
echo "DRUPAL_INSTANCES=${DRUPAL_INSTANCES}" | tee -a $GITHUB_ENV
echo "DRUPAL_MEMORY=${DRUPAL_MEMORY}" | tee -a $GITHUB_ENV
echo "GSA_AUTH_KEY=${GSA_AUTH_KEY}" | tee -a $GITHUB_ENV
echo "HASH_SALT=${{ secrets.HASH_SALT }}" | tee -a $GITHUB_ENV
echo "WAF_NAME=waf"| tee -a $GITHUB_ENV

if [ "${COMPOSER_DEV}" = "1" ]; then
  sed -i 's/--no-dev //' .bp-config/options.json || exit 0
fi