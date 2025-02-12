#!/bin/bash
set -uo pipefail

## Export proxy servers.
#export http_proxy=$(echo ${VCAP_SERVICES} | jq -r '."user-provided"[].credentials.proxy_uri')
#export https_proxy=$(echo ${VCAP_SERVICES} | jq -r '."user-provided"[].credentials.proxy_uri')

export home="/home/vcap"
export app_path="${home}/app"

#echo "${VCAP_SERVICES" | jq -r '."user-provided"[].credentials.ca_certificate' | base64 -d > ${app_path}/ca_certificate.pem
#echo "${VCAP_SERVICES" jq -r '."user-provided"[].credentials.ca_key' | base64 -d > ${app_path}/ca_key.pem

#chmod 600 ${app_path}/ca_certificate.pem
#chmod 600 ${app_path}/ca_key.pem

if [ -z "${VCAP_SERVICES:-}" ]; then
    echo "VCAP_SERVICES must a be set in the environment: aborting bootstrap";
    exit 1;
fi

export apt_path="${home}/deps/0/apt"
export apt_bin_path="${home}/deps/0/bin"

## NewRelic configuration
export newrelic_apt="${apt_path}/usr/lib/newrelic-php5"
export newrelic_app="${app_path}/newrelic"

rm -rf ${newrelic_app}
ln -s "${newrelic_apt}" "${newrelic_app}"

mkdir -p "${newrelic_app}/daemon"

ln -s ${apt_bin_path}/newrelic-daemon ${newrelic_app}/daemon/newrelic-daemon.x64

echo -e "\n" | tee -a ${app_path}/php/etc/php.ini
echo 'newrelic.daemon.collector_host=gov-collector.newrelic.com' | tee -a ${app_path}/php/etc/php.ini

source "${app_path}/scripts/bash_exports.sh"

if [ ! -f ./container_start_timestamp ]; then
  touch ./container_start_timestamp
  chmod a+r ./container_start_timestamp
  echo "$(date +'%s')" > ./container_start_timestamp
fi

dirs=( "${HOME}/private" "${HOME}/web/sites/default/files" )

for dir in "${dirs[@]}"; do
  if [ ! -d "${dir}" ]; then
    echo "Creating ${dir} directory ... "
    mkdir "${dir}"
    chown vcap. "${dir}"
  fi
done

## Updated ~/.bashrc to update $PATH when someone logs in.
[ -z "$(cat ${home}/.bashrc | grep PATH)" ] && \
  touch ${home}/.bashrc && \
  echo "alias nano=\"${home}/deps/0/apt/bin/nano\"" >> ${home}/.bashrc && \
  echo "PATH=$PATH:/home/vcap/app/php/bin:/home/vcap/app/vendor/drush/drush" >> /home/vcap/.bashrc

source ${home}/.bashrc

echo "Installing awscli..."
{
  curl -S "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "/tmp/awscliv2.zip"
  unzip -qq /tmp/awscliv2.zip -d /tmp/
  /tmp/aws/install --bin-dir ${home}/deps/0/bin --install-dir ${home}/deps/0/usr/local/aws-cli
  rm -rf /tmp/awscliv2.zip /tmp/aws
} >/dev/null 2>&1

# if [ "${CF_INSTANCE_INDEX:-''}" == "0" ]; then
#   ${app_path}/scripts/post-deploy
# fi