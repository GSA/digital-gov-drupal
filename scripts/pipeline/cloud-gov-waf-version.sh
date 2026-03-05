#!/bin/bash
#
# This is where to set the desired version of nginx. This will be specified in the
# buildpack manifest for the WAF, and in the modsecurity plugin build (see terraform-build-waf-plugin.sh)
#

# This script is a stub, to be replaced when we revisit how we manage these variables.
# It used to determine the latest available version of nginx from the
# available buildpack and the information about it on GitHub, but there
# isn't a stable API for that. Instead, we decided to specify the version we want
# include updating it in our regular review process.

# NB: Mainline nginx versions are denoted by an even number in the second part of the version number.
NGINX_VERSION=1.28.1


export nginx_version=${NGINX_VERSION}
echo "nginx_version=${NGINX_VERSION}"


