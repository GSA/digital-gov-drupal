#!/bin/bash

set -e

if [ "$(uname -s)" = "Darwin" ]; then
  if ! hash brew 2>/dev/null ; then
    echo "Please install Homebrew:
    /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
    echo
    echo "NOTE: You will need sudoer permission."
    echo "Linux: https://linuxize.com/post/how-to-add-user-to-sudoers-in-ubuntu/"
    echo "MacOS: https://osxdaily.com/2014/02/06/add-user-sudoers-file-mac/"
    exit 1
  fi

  if ! hash gdate 2>/dev/null ; then
    echo "Please install GNU coreutils:
    Homebrew:
      brew install coreutils"
    exit 1
  fi
fi

if ! hash cf 2>/dev/null ; then
  echo "Please install cf version 8:
    Linux: https://docs.cloudfoundry.org/cf-cli/install-go-cli.html
    Homebrew:
      brew tap cloudfoundry/tap
      brew install cf-cli@8"
  exit 1
elif [[ "$(cf --version)" != *"cf version 8."* ]]; then
  echo "Please install cf version 8:
  Linux: https://docs.cloudfoundry.org/cf-cli/install-go-cli.html
  Homebrew:
    brew uninstall cf-cli
    brew tap cloudfoundry/tap
    brew install cf-cli@8"
  exit 1
fi

if ! hash jq 2>/dev/null ; then
  echo "Please install jq:
    Linux: https://jqlang.github.io/jq/download/
    Homebrew:
      brew install jq"
  exit 1
fi

# change which date command is used based on host OS
date_command=''

if [ "$(uname -s)" == "Darwin" ]; then
  date_command=gdate
else
  date_command=date
fi

help(){
  echo "Usage: $0 [options]" >&2
  echo
  echo "   -b           The name of the S3 bucket with the backup."
  echo "   -e           Environment of backup to download."
  echo "   -s           Name of the space the backup bucket is in."
  echo "   -d           Date to retrieve backup from. Acceptable values
                are 'latest' or in 'YYYY-MM-DD' format and no
                more than 15 days ago."
}

RED='\033[0;31m'
NC='\033[0m'

while getopts 'b:e:s:d:' flag; do
  case ${flag} in
    b) backup_bucket=${OPTARG} ;;
    e) env=${OPTARG} ;;
    s) space=${OPTARG} ;;
    d) retrieve_date=${OPTARG} ;;
    *) help && exit 1 ;;
  esac
done

[[ -z "${backup_bucket}" ]] && help && echo -e "\n${RED}Error: Missing -b flag.${NC}" && exit 1
[[ -z "${env}" ]] && help && echo -e "\n${RED}Error: Missing -e flag.${NC}" && exit 1
[[ -z "${space}" ]] && help && echo -e "\n${RED}Error: Missing -s flag.${NC}" && exit 1
[[ -z "${retrieve_date}" ]] && help && echo -e "\n${RED}Error: Missing -d flag.${NC}" && exit 1

echo "Getting backup bucket credentials..."
{
  cf target -s "${space}"

  export service="${backup_bucket}"
  export service_key="${service}-key"
  cf delete-service-key "${service}" "${service_key}" -f
  cf create-service-key "${service}" "${service_key}"
  sleep 2
  export s3_credentials=$(cf service-key "${service}" "${service_key}" | tail -n +2)

  export AWS_ACCESS_KEY_ID=$(echo "${s3_credentials}" | jq -r '.credentials.access_key_id')
  export bucket=$(echo "${s3_credentials}" | jq -r '.credentials.bucket')
  export AWS_DEFAULT_REGION=$(echo "${s3_credentials}" | jq -r '.credentials.region')
  export AWS_SECRET_ACCESS_KEY=$(echo "${s3_credentials}" | jq -r '.credentials.secret_access_key')

} >/dev/null 2>&1

echo "Downloading backup..."
{

  aws s3 cp s3://${bucket}/${env}/${retrieve_date}.tar.gz . --no-verify-ssl 2>/dev/null
  cf delete-service-key "${service}" "${service_key}" -f

} >/dev/null 2>&1

echo "File saved: ${retrieve_date}.tar.gz"
