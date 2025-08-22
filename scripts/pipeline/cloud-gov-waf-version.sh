#!/bin/bash

function version {
  echo "$@" | awk -F. '{ printf("%d%03d%03d%03d\n", $1,$2,$3,$4); }';
}

if [ -z "$(which pup)" ] ; then
  if [ "$(whoami)" != "root" ] ; then
    sudo wget -q --show-progress https://github.com/ericchiang/pup/releases/download/v0.4.0/pup_v0.4.0_linux_amd64.zip
    sudo unzip pup_v0.4.0_linux_amd64.zip -d /usr/local/bin
  else
    wget -q --show-progress https://github.com/ericchiang/pup/releases/download/v0.4.0/pup_v0.4.0_linux_amd64.zip
    unzip pup_v0.4.0_linux_amd64.zip -d /usr/local/bin
  fi
fi

# This is probably going to be called in a pipeline that's targeted TF_BACKEND_SPACE
return_to_space=$( cf target | grep space: | awk '{ print $2 }')
cf target -s ${CF_SPACE}

declare CURRENT_BP_VERSION
CURRENT_BP_VERSION=$(cf app "${PROJECT}-waf-${CF_SPACE}" | grep nginx_buildpack | awk '{print $2}')

# "filename" is the seventh field in `cf buildpacks` output. 2025-08-15.
declare NEW_BP_VERSION
NEW_BP_VERSION=$(cf buildpacks | grep nginx | grep cflinuxfs4 | awk '{print $7}' | grep -Eo '[0-9]\.[0-9]?(.[0-9]+)')

new_bp_version=$(version "${NEW_BP_VERSION}")
current_bp_version=$(version "${CURRENT_BP_VERSION}")

curl -Ls "https://raw.githubusercontent.com/cloudfoundry/nginx-buildpack/refs/tags/v${CURRENT_BP_VERSION}/manifest.yml" > current_manifest.yml
declare current_nginx_version
current_nginx_version=$(yq  eval '.dependencies[] | select(.name == "nginx") | .version' current_manifest.yml | sort -r | head -n 1 )

curl -Ls "https://raw.githubusercontent.com/cloudfoundry/nginx-buildpack/refs/tags/v${NEW_BP_VERSION}/manifest.yml" > new_manifest.yml
declare new_nginx_version
new_nginx_version=$(yq  eval '.dependencies[] | select(.name == "nginx") | .version' new_manifest.yml | sort -r | head -n 1 )

echo "new_nginx_version=${new_nginx_version}" | tee -a "${GITHUB_OUTPUT}"
echo "current_nginx_version=${current_nginx_version}" | tee -a "${GITHUB_OUTPUT}"
echo "current_bp_version=${CURRENT_BP_VERSION}" | tee -a "${GITHUB_OUTPUT}"
echo "new_bp_version=${NEW_BP_VERSION}" | tee -a "${GITHUB_OUTPUT}"

export new_nginx_version=${new_nginx_version}
export current_nginx_version=${current_nginx_version}
export current_bp_version=${CURRENT_BP_VERSION}
export new_bp_version=${NEW_BP_VERSION}

if [ "${new_bp_version}" != "${current_bp_version}" ]; then
  echo "New version of buildpack found!"
  echo "update=true" | tee -a "${GITHUB_OUTPUT}"
  export update=true
else
  echo "Running latest version of the buildpack!"
fi

echo "new_nginx_version=${new_nginx_version}"
echo "current_nginx_version=${current_nginx_version}"
echo "current_bp_version=${CURRENT_BP_VERSION}"
echo "new_bp_version=${NEW_BP_VERSION}"

cf target -s ${return_to_space}
