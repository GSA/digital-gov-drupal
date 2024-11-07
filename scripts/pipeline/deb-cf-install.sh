#!/bin/bash

echo "Installing CloudFoundry repository..."
{
  curl -L "https://packages.cloudfoundry.org/stable?release=linux64-binary&version=v8&source=github" | tar -zx
  if [ "$(whoami)" != "root" ]; then
    sudo mv cf cf8 /usr/local/bin
  else
    mv cf cf8 /usr/local/bin
  fi
} >/dev/null 2>&1
