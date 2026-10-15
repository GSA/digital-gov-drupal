#!/bin/bash
set -uo pipefail


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

## Egress proxy.
##
## http_proxy/https_proxy are deliberately NOT exported. Each consumer opts in
## individually instead, so that S3 traffic keeps going direct -- the AWS S3 Gateway
## ranges are already permitted by trusted_local_networks_egress, and routing
## `aws s3 sync` through the proxy would break the static site build in scripts/upkeep.
##
## Located by tag rather than service name, matching how settings.cloudgov.php finds
## the cache service. Empty when no proxy is bound, which is the normal state in an
## environment the proxy has not been rolled out to yet.
proxy_uri=$(echo "${VCAP_SERVICES}" | jq -r '[."user-provided"[]? | select(any(.tags[]?; . == "egress-proxy")) | .credentials.proxy_uri] | first // empty')

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

## Route the New Relic daemon through the egress proxy, when one is bound.
##
## The daemon does NOT honour http_proxy/https_proxy -- it only reads this ini key, so
## without it New Relic silently stops reporting once the space loses public egress.
## The CA bundle is needed because the proxy URL is https:// to an internal route.
if [ -n "${proxy_uri}" ]; then
  echo "Routing the New Relic daemon through the egress proxy ... "
  for setting in \
    "newrelic.daemon.proxy = \"${proxy_uri}\"" \
    "newrelic.daemon.ssl_ca_bundle = \"/etc/ssl/certs/ca-certificates.crt\"" \
    "newrelic.daemon.ssl_ca_path = \"/etc/ssl/certs/\"" ; do
    key="${setting%% *}"
    ## Drop any existing definition, then append. Avoids putting the value on the
    ## right-hand side of a sed expression, where a & \ or | in a generated credential
    ## would be interpreted rather than written literally.
    ## -E for portability: "\?" in a basic regex is a GNU extension.
    sed -i -E "/^;?[[:space:]]*${key}[[:space:]]*=/d" "${php_ini_d_path}/newrelic.ini"
    printf '%s\n' "${setting}" >> "${php_ini_d_path}/newrelic.ini"
  done
else
  echo "No egress proxy bound; the New Relic daemon will connect directly."
fi

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

## This runs on EVERY container start, not at staging, so it needs egress every time
## an application instance or task starts. awscli.amazonaws.com is a CloudFront host --
## it is not covered by the AWS S3 Gateway ranges in trusted_local_networks_egress -- so
## once the space loses public egress this must go through the proxy.
##
## Without it there is no `aws` binary, and scripts/upkeep dies with exit 127 partway
## through the static site build.
echo "Installing awscli..."
awscli_curl=(curl -sS --fail)
if [ -n "${proxy_uri}" ]; then
  awscli_curl+=(--proxy "${proxy_uri}")
fi
{
  "${awscli_curl[@]}" "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "/tmp/awscliv2.zip" &&
  unzip -qq /tmp/awscliv2.zip -d /tmp/ &&
  /tmp/aws/install --bin-dir ${home}/deps/0/bin --install-dir ${home}/deps/0/usr/local/aws-cli
} || echo "ERROR: awscli install failed -- anything using 'aws' will fail with exit 127"
rm -rf /tmp/awscliv2.zip /tmp/aws

if [ ! -x "${home}/deps/0/bin/aws" ]; then
  echo "ERROR: ${home}/deps/0/bin/aws is missing after install"
fi
