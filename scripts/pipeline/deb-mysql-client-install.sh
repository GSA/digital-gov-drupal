#!/bin/bash

echo "Installing MySQL client..."
{
    ## To work for rootless and root images.
    if [ "$(whoami)" != "root" ]; then
      sudo apt-get update
      sudo apt-get install -y mysql-client-8.0
    else
      apt-get update
      apt-get install -y mysql-client-8.0
    fi
} >/dev/null 2>&1
