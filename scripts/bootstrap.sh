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

export deps_path="${home}/deps/0"
export apt_path="${deps_path}/apt"
export apt_bin_path="${deps_path}/bin"

php_api_version=$(php -i | grep "PHP API" | cut -d' ' -f4)

## NewRelic configuration
application_name=$(echo "$VCAP_APPLICATION" | jq -r '.application_name')
newrelic_key=$(echo "$VCAP_SERVICES" | jq -r '."user-provided"[] | select(.name | contains("secrets")) | .credentials | .newrelic_key')
newrelic_ini=$(find ${home} -name "newrelic.ini*")
newrelic_so=$(find ${home} -name "newrelic*${php_api_version}*.so")
php_ini_d_path="${app_path}/php/etc/php.ini.d"

## Create link to New Relic PHP module.
ln -s "${newrelic_so}" "${app_path}/php/lib/newrelic.so"

## Create link to New Relic PHP ini configuration file.
ln -s "${newrelic_ini}" "${php_ini_d_path}/newrelic.ini"

## Edit New Relic PHP ini configuration file.
sed -i "s|extension = \"newrelic.so\"|extension = \"${app_path}/php/lib/newrelic.so\"|" "${php_ini_d_path}/newrelic.ini"
sed -i "s/newrelic.appname = \"PHP Application\"/newrelic.appname = \"${application_name}\"/" "${php_ini_d_path}/newrelic.ini"
sed -i 's/;newrelic.daemon.collector_host = ""/newrelic.daemon.collector_host="gov-collector.newrelic.com"/' "${php_ini_d_path}/newrelic.ini"
sed -i "s|;newrelic.daemon.location = \"/usr/bin/newrelic-daemon\"|newrelic.daemon.location = \"${apt_bin_path}/newrelic-daemon\"|" "${php_ini_d_path}/newrelic.ini"
sed -i 's|newrelic.daemon.logfile = "/var/log/newrelic/newrelic-daemon.log"|newrelic.daemon.logfile = "/dev/stdout"|' "${php_ini_d_path}/newrelic.ini"
sed -i "s|;newrelic.daemon.pidfile = \"\"|newrelic.daemon.pidfile = \"/${home}/newrelic_daemon.pid\"|" "${php_ini_d_path}/newrelic.ini"
sed -i "s/newrelic.license = \"REPLACE_WITH_REAL_KEY\"/newrelic.license = \"${newrelic_key}\"/" "${php_ini_d_path}/newrelic.ini"
sed -i 's|newrelic.logfile = "/var/log/newrelic/php_agent.log"|newrelic.logfile = "/dev/stdout"|' "${php_ini_d_path}/newrelic.ini"

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
