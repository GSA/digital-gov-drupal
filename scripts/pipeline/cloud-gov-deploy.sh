#!/bin/bash

mv manifest.yml manifest.tmp

# Convert to uppercase
CF_SPACE_UPPER=${CF_SPACE^^}

DRUSH_OPTIONS_URI_VAR_NAME="${CF_SPACE_UPPER}_CMS_URL"
export DRUSH_OPTIONS_URI="${!DRUSH_OPTIONS_URI_VAR_NAME}"

STATIC_URI_VAR_NAME="${CF_SPACE_UPPER}_STATIC_URL"
export STATIC_URI="${!STATIC_URI_VAR_NAME}"

CMS_URI_VAR_NAME="${CF_SPACE_UPPER}_CMS_URL"
export CMS_URI="${!CMS_URI_VAR_NAME}"

STATIC_FQDN=$(sed -E 's/^\s*.*:\/\///g' "${STATIC_URI}")
CMS_FQDN=$(sed -E 's/^\s*.*:\/\///g' "${CMS_URI}")

envsubst < manifest.tmp > manifest.yml
cat manifest.tmp
cat manifest.yml

cf push --strategy rolling

cf add-network-policy "${PROJECT}-${APP_NAME}-${CF_SPACE}" "${PROJECT}-${WAF_NAME}-${CF_SPACE}" -s "${CF_SPACE}" --protocol tcp --port "${BUILDPACK_PORT}"
cf add-network-policy "${PROJECT}-${WAF_NAME}-${CF_SPACE}" "${PROJECT}-${APP_NAME}-${CF_SPACE}" -s "${CF_SPACE}" --protocol tcp --port "${BUILDPACK_PORT}"

echo "Exporting routes for ${CF_SPACE}..."
{
  if [ "${CF_SPACE_UPPER}" = "PROD" ]; then
    cf map-route "${PROJECT}-${WAF_NAME}-${CF_SPACE}" "${CMS_FQDN}" --app-protocol http1 || true
    cf map-route "${PROJECT}-${WAF_NAME}-${CF_SPACE}" "${STATIC_FQDN}" --app-protocol http1 || true
  else
    cf map-route "${PROJECT}-${WAF_NAME}-${CF_SPACE}" app.cloud.gov --hostname "${PROJECT}-${STATIC_NAME}-${CF_SPACE}" --app-protocol http1 || true
    cf map-route "${PROJECT}-${WAF_NAME}-${CF_SPACE}" app.cloud.gov --hostname "${PROJECT}-${APP_NAME}-${CF_SPACE}" --app-protocol http1  || true
  fi
}