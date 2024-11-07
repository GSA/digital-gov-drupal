#!/bin/bash

## To work for rootless and root images.
echo "Installing composer..."
{
  EXPECTED_CHECKSUM="$(php -r 'copy("https://composer.github.io/installer.sig", "php://stdout");')"
  php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
  ACTUAL_CHECKSUM="$(php -r "echo hash_file('sha384', 'composer-setup.php');")"
  if [ "$EXPECTED_CHECKSUM" != "$ACTUAL_CHECKSUM" ]; then
    >&2 echo 'ERROR: Invalid installer checksum'
    rm composer-setup.php
    exit 1
  fi

  php composer-setup.php --quiet
  RESULT=$?
  rm composer-setup.php
 
  chmod +x composer.phar
  if [ "$(whoami)" != "root" ]; then
    sudo mv composer.phar /usr/local/bin/composer
  else
    mv composer.phar /usr/local/bin/composer
  fi
  exit $RESULT
} >/dev/null 2>&1