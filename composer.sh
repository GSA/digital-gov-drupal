#!/usr/bin/env bash

cd "$(dirname "$0")" || exit

EXIT_STATUS=0

set -x
./php.sh vendor/bin/robo common:composer -- "$@" || EXIT_STATUS=$?
set +x

# Support MacOS and Linux.
# https://stackoverflow.com/questions/8996820/how-to-create-md5-hash-in-bash-in-mac-os-x/8996924#8996924
__rvm_md5_for()
{
  # Macos.
  if builtin command -v md5 > /dev/null; then
    echo "$1" | md5
  # Linux.
  elif builtin command -v md5sum > /dev/null ; then
    echo "$1" | md5sum | awk '{print $1}'
  else
    rvm_error "Neither md5 nor md5sum were found in the PATH"
    return 1
  fi

  return 0
}

# During the build process, the git repo is removed and a 'updated' will throw a
# warning, ensure there is a git repo first.
if [ "$(git rev-parse --is-inside-work-tree 2>/dev/null)" = "true" ]; then
  # If the composer.lock has been modified, then add the command used to composer.log
  updated=$(git diff --name-only composer.lock)
  if [[ -n $updated ]]; then
    # Create a hash of the diff of what's in composer.lock.
    temp_hash=$(git diff composer.lock)
    hash=$(__rvm_md5_for "$temp_hash")
    if [ ! -f composer.log ]; then
      touch composer.log
    fi
    # Look at the log file for the last hash of compose.lock that was created.
    last_hash=$(tail -1 composer.log | sed 's/|.*//')
    # If the stored hash of the last item is the same as the current diff hash,
    # then the command has already been recorded. The command given might not
    # even be the last command run, but the last_hash is based on the diff not the command.
    if [[ "$last_hash" = "$hash" ]]; then
      exit "${EXIT_STATUS}"
    fi
    branch=$(git rev-parse --abbrev-ref HEAD)
    # If rebasing, the branch name will be HEAD. Use another method to get it.\
    # Digital.gov custom change.
    if [[ "$branch" = 'HEAD' ]]; then
      rebasing-branch() {
          for location in rebase-merge rebase-apply; do
              path=$(git rev-parse --git-path ${location})
              if test -d ${path}; then
                  revision=$(<${path}/head-name)
                  echo ${revision##refs/heads/}
                  return 0
              fi
          done
      }
      branch=$(rebasing-branch)
    fi
    date=$(date)
    email=$(git config user.name)
    echo -e "$hash|$email|$branch|$date|./composer.sh $*" >> composer.log
  fi
fi

exit "${EXIT_STATUS}"
