#!/bin/bash

APP_NAME=$1
command=$2
show_output=$3

APP_GUID=$(cf app "${APP_NAME}" --guid)
bin_path="/var/www/vendor/bin/:/home/vcap/deps/0/bin/"

[ -z "${APP_NAME}" ] || [ -z "${command}" ] && echo "Command error! Valid format: ${0} <application_name> <command>" && exit 1

ssh_config=/tmp/ssh_config
ssh_passwd="/tmp/ssh_password"

precommand="touch ~/exports.sh && source ~/exports.sh && PATH=\$PATH:${bin_path}"

cat >${ssh_config} <<EOL
Host ssh.fr.cloud.gov
  Hostname ssh.fr.cloud.gov
  Port 2222
  User cf:${APP_GUID}/0
  StrictHostKeyChecking no
  RequestTTY force
EOL

cf ssh-code > ${ssh_passwd}

if [ -z "${show_output}" ]; then
  echo "Running command: '$(echo "${command}" | cut -d' ' -f1,2)'..."
  {
    sshpass -f "${ssh_passwd}" ssh -F "${ssh_config}" "ssh.fr.cloud.gov" "${precommand} ${command}"
  } >/dev/null 2>&1
else
  sshpass -f "${ssh_passwd}" ssh -F "${ssh_config}" "ssh.fr.cloud.gov" "${precommand} ${command}"
fi