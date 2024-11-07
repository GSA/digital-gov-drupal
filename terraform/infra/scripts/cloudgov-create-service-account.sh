#!/bin/bash

org=""
prefix=""
deploy_space=""
spaces=""

current_path=$(pwd)
tfvars_file="terraform.tfvars"

help(){
  echo "Usage: $0 [options]" >&2
  echo
  echo "   -d           Space to create the service token in. Likely production."
  echo "   -o           Name of the Cloud.gov organization."
  echo "   -p           Name of the service account prefix."
  echo "   -s           List of spaces in your project. This gives the service account developer access to them."
}

while getopts 'd:ho:p:s:' flag; do
  case "${flag}" in
    d) deploy_space="${OPTARG}" ;;
    h) help && exit 0 ;;
    o) org="${OPTARG}" ;;
    p) prefix="${OPTARG}-" ;;
    s) spaces=(${OPTARG}) ;;
    *) help && exit 1 ;;
  esac
done

[[ -z "${org}" ]] && help && exit 1
[[ -z "${prefix}" ]] && help && exit 1
[[ -z "${deploy_space}" ]] && help && exit 1
[[ -z "${spaces}" ]] && help && exit 1

current_space=$(cf target | grep space -A 1 | awk '{print $2}')

echo "Changing target space to the deployment space..."
{
  cf target -s ${deploy_space}
} >/dev/null 2>&1

echo "Checking service key..."
while : ; do
  {
    service_key=$(cf service-key ${prefix}svc ${prefix}svc-key | sed '1,2d')
  } >/dev/null 2>&1
  
  if [[ ${service_key} == "" ]]; then
    echo "Service key is missing!"
    echo "Creating service account..."
    # {
      cf create-service cloud-gov-service-account space-deployer ${prefix}svc
    # } >/dev/null 2>&1
    echo "Creating service key..."
    # {
      cf create-service-key ${prefix}svc ${prefix}svc-key
    # } >/dev/null 2>&1
  else
    export cloudgov_password=$(echo ${service_key} | jq -r '.credentials.password')
    export cloudgov_username=$(echo ${service_key} | jq -r '.credentials.username')

    for space in ${spaces[@]}; do
      echo "Adding '${space}' to service account..."
      cf set-space-role ${cloudgov_username} ${org} ${space} SpaceDeveloper 
      # >/dev/null 2>&1

      echo "Allowing internet access for '${space}' deployment staging..."
      cf bind-security-group public_networks ${org} --space ${space} --lifecycle staging 
      # >/dev/null 2>&1
    done
    break
  fi
  sleep 1
done

echo "Changing target space to the previous space..."
{
  cf target -s ${current_space}
} >/dev/null 2>&1

cp terraform.tfvars terraform.tfvars.tmp
envsubst '$cloudgov_password,$cloudgov_username' < "${tfvars_file}.tmp" > ${tfvars_file}
rm ${tfvars_file}.tmp