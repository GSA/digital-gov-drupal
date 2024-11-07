#!/bin/bash

echo "Installing PHP CodeSniffer..."
{
  git clone --branch 8.3.x http://git.drupal.org/project/coder.git
  cd coder
  composer install
  cd ..
  export PATH="$PATH:$HOME/project/coder/vendor/bin"
} >/dev/null 2>&1