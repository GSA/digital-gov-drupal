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

cf target -s ${CF_SPACE}

declare CURRENT_BP_VERSION
CURRENT_BP_VERSION=$(cf app "${PROJECT}-waf-${CF_SPACE}" | grep nginx_buildpack | xargs | awk '{print $2}')

declare NEW_BP_VERSION
NEW_BP_VERSION=$(cf buildpacks | grep nginx | grep cflinuxfs4 | awk '{print $NF}' | grep -Eo '[0-9]\.[0-9]?(.[0-9]+)')

new_bp_version=$(version "${NEW_BP_VERSION}")
current_bp_version=$(version "${CURRENT_BP_VERSION}")

curl -Ls "https://github.com/cloudfoundry/nginx-buildpack/releases/tag/v${CURRENT_BP_VERSION}" > /tmp/current_bp_version
declare current_nginx_version
current_nginx_version=$(cat /tmp/current_bp_version | pup 'table json{}' | jq -r '.[].children[].children[] | select(.children[].text == "nginx") | select(.children[].text == "cflinuxfs4") | .children[].text' | tr '\n' ' ' | sed -E 's/cflinuxfs4 /cflinuxfs4\n/g' | sort -r | head -n 1 | awk '{print $2}')

curl -Ls "https://github.com/cloudfoundry/nginx-buildpack/releases/tag/v${NEW_BP_VERSION}" > /tmp/new_nginx_version
declare default_nginx_binary_version
default_nginx_binary_version=$(cat /tmp/new_nginx_version | pup 'table json{}' | jq -r '.[].children[].children[] | select(.children[].text == "nginx") | select(.children[].text | contains(".x")) | .children[].text' | grep -v nginx | sed 's/.\{1\}$//')

declare new_nginx_version
new_nginx_version=$(cat /tmp/new_nginx_version | pup 'table json{}' | jq -r ".[].children[].children[] | select(.children[].text == \"nginx\") | select(.children[].text == \"cflinuxfs4\") | select(.children[].text | contains(\"${default_nginx_binary_version}\")) | .children[].text" | tr '\n' ' ' | sed -E 's/cflinuxfs4 /cflinuxfs4\n/g' | sort -r | head -n 1 | awk '{print $2}')


echo "new_nginx_version=${new_nginx_version}" | tee -a "${GITHUB_OUTPUT}"
echo "current_nginx_version=${current_nginx_version}" | tee -a "${GITHUB_OUTPUT}"
echo "current_bp_version=${CURRENT_BP_VERSION}" | tee -a "${GITHUB_OUTPUT}"
echo "new_bp_version=${NEW_BP_VERSION}" | tee -a "${GITHUB_OUTPUT}"

export new_nginx_version=${new_nginx_version}
export current_nginx_version=${current_nginx_version}
export current_bp_version=${CURRENT_BP_VERSION}
export new_bp_version=${NEW_BP_VERSION}

if [ "${new_bp_version}" -ne "${current_bp_version}" ]; then
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
