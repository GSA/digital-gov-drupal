#!/bin/bash

[ -z "${new_nginx_version}" ] && echo "NGINX version not set!" && exit 1
[ -z "${modsecurity_nginx_version}" ] && echo "Modsecurity version not set!" && exit 1
[ -z "${ubuntu_version}" ] && echo "Ubuntu version not set!" && exit 1

## The current root path.
CWD=$(pwd)

## Path to the WAF application.
APP_PATH=terraform/applications/nginx-waf

## Change directory to the Dockerfile path.
cd "${APP_PATH}/.docker/" || exit 1

## Run make, which builds the module and moves it to '../modules/'.
make

## Change directory back to the root path.
cd "${CWD}" || exit 1

## Make sure the module directory on the bastion exists.
./scripts/pipeline/cloud-gov-remote-command.sh "${TF_BASTION}" "mkdir -p ${REPO_NAME}/${APP_PATH}/modules/"

## SCP the module to the bastion.
./scripts/pipeline/cloud-gov-scp-file.sh "${TF_BASTION}" "${APP_PATH}/modules/" "${REPO_NAME}/${APP_PATH}/"