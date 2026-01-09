#!/bin/bash

cf_package="https://packages.cloudfoundry.org/stable?release=linux64-binary&version=v8&source=github"

echo "Installing CloudFoundry repository..."
{
  curl -L "${cf_package}" | tar -zx

  if [ "$(whoami)" != "root" ]; then
    sudo mv cf cf8 /usr/local/bin
  else
    mv cf cf8 /usr/local/bin
  fi

  cf install-plugin -f https://github.com/cloud-gov/cf-service-connect/releases/download/v1.1.4/cf-service-connect_linux_amd64

} >/dev/null 2>&1
