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
  echo "   -c           The name of the CF service containing the S3 bucket with the backup."
  echo "   -s           Name of the space the backup bucket is in."
  echo "   -d           Date to retrieve backup from. Acceptable values
                are 'latest' or in 'YYYY-MM-DD' format and no
                more than 15 days ago."
}

RED='\033[0;31m'
NC='\033[0m'

while getopts 'c:e:s:d:' flag; do
  case ${flag} in
    c) cf_s3_service=${OPTARG} ;;
    s) space=${OPTARG} ;;
    d) retrieve_date=${OPTARG} ;;
    *) help && exit 1 ;;
  esac
done

[[ -z "${cf_s3_service}" ]] && help && echo -e "\n${RED}Error: Missing -b flag.${NC}" && exit 1
[[ -z "${space}" ]] && help && echo -e "\n${RED}Error: Missing -s flag.${NC}" && exit 1
[[ -z "${retrieve_date}" ]] && help && echo -e "\n${RED}Error: Missing -d flag.${NC}" && exit 1

echo "Getting backup bucket credentials for $cf_s3_service in $space ..."
{
  cf target -s "${space}"
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  . "${script_dir}/cloud-gov-s3-creds.sh" ${cf_s3_service}
  export bucket="${AWS_BUCKET}"
} &>/dev/null
[ $? -ne 0 ] && echo -e "\n${RED}Error: Failed to get backup bucket credentials.${NC}" && exit 1

echo "Downloading backup from $bucket..."
{
  aws s3 cp s3://${bucket}/${retrieve_date}.sql.gz . --no-verify-ssl
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  . "${script_dir}/cloud-gov-s3-creds.sh" -d
} &>/dev/null
[ $? -ne 0 ] && echo -e "\n${RED}Error: Failed to download backup from S3 bucket.${NC}" && exit 1

echo "File saved: ${retrieve_date}.tar.gz"
