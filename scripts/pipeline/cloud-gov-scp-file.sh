#!/bin/bash

APP_NAME=$1
LOCAL=$2
REMOTE=$3

APP_GUID=$(cf app "${APP_NAME}" --guid)

ssh_config=/tmp/ssh_config
ssh_passwd="/tmp/ssh_password"

cat >${ssh_config} <<EOL
Host ssh.fr.cloud.gov
  Hostname ssh.fr.cloud.gov
  Port 2222
  User cf:${APP_GUID}/0
  StrictHostKeyChecking no
EOL

cf ssh-code > ${ssh_passwd}

if [ -d "${LOCAL}" ]; then
  echo "Uploading folder '${LOCAL}'..."
  sshpass -f "${ssh_passwd}" scp -F ${ssh_config} -r "${LOCAL}" "ssh.fr.cloud.gov:${REMOTE}"
else
  echo "Uploading file '${LOCAL}'..."
  sshpass -f "${ssh_passwd}" scp -F ${ssh_config} "${LOCAL}" "ssh.fr.cloud.gov:${REMOTE}"
fi

echo "Upload complete."