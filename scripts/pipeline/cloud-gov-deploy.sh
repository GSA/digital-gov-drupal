#!/bin/bash

mv manifest.yml manifest.tmp
envsubst < manifest.tmp > manifest.yml

cf push --strategy rolling

cf add-network-policy "${PROJECT}-${APP_NAME}-${CF_SPACE}" "${PROJECT}-${WAF_NAME}-${CF_SPACE}" -s "${CF_SPACE}" --protocol tcp --port ${BUILDPACK_PORT}
cf add-network-policy "${PROJECT}-${WAF_NAME}-${CF_SPACE}" "${PROJECT}-${APP_NAME}-${CF_SPACE}" -s "${CF_SPACE}" --protocol tcp --port ${BUILDPACK_PORT}
