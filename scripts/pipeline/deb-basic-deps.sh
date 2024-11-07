#!/bin/bash

## To work for rootless and root images.
echo "Installing basic dependencies..."
{
  if [ "$(whoami)" != "root" ]; then
    sudo apt-get update
    sudo apt-get install -y curl gettext
  else
    apt-get update
    apt-get install -y curl gettext
  fi
} >/dev/null 2>&1
