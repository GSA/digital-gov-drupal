#!/bin/bash
#
# Enforce the egress security-group posture for one environment.
#
# Desired state:
#   shared-egress   public_networks_egress BOUND    (running and staging)
#   <app space>     public_networks_egress UNBOUND  (running only)
#   <app space>     staging lifecycle               UNTOUCHED
#
# The staging lifecycle of the application space must keep public egress: the apt
# buildpack fetches from apt.newrelic.com, scripts/bootstrap.sh downloads the AWS CLI
# from awscli.amazonaws.com, and the PHP buildpack pulls from packages.cloudfoundry.org.
# Only the RUNNING lifecycle is locked down.
#
# This is a script rather than Terraform for two reasons:
#
#   1. Terraform can assert that a binding EXISTS but cannot assert that one is ABSENT,
#      and the absence is the entire point of this step.
#   2. The shared-egress binding is a singleton shared by every environment, whereas the
#      egress configuration runs once per workspace. Three workspace states cannot each
#      own the same binding.
#
# Being idempotent, it doubles as drift correction: if public egress is re-bound to an
# application space by hand, the next deploy removes it again.
#
# Required environment: CF_ORG, CF_SPACE, PROJECT, APP_NAME

set -o pipefail

EGRESS_SPACE="${EGRESS_SPACE:-shared-egress}"
GROUP="public_networks_egress"
CLIENT_APP="${PROJECT}-${APP_NAME}-${CF_SPACE}"

for required in CF_ORG CF_SPACE PROJECT APP_NAME; do
  if [ -z "${!required}" ]; then
    echo "ERROR: ${required} must be set"
    exit 1
  fi
done

## Resolved once and reused.
org_guid=$(cf curl "/v3/organizations?names=${CF_ORG}" 2>/dev/null | jq -r '.resources[0].guid // empty')
group_guid=$(cf curl "/v3/security_groups?names=${GROUP}" 2>/dev/null | jq -r '.resources[0].guid // empty')

if [ -z "${org_guid}" ] || [ -z "${group_guid}" ]; then
  echo "ERROR: could not resolve org '${CF_ORG}' or security group '${GROUP}'"
  exit 1
fi

space_guid() {
  cf curl "/v3/spaces?names=$1&organization_guids=${org_guid}" 2>/dev/null \
    | jq -r '.resources[0].guid // empty'
}

## Is $GROUP bound to space $1 for lifecycle $2?
##
## Reads /v3 rather than parsing `cf security-groups` human output. The CLI table was
## proven to work, but if its column layout ever shifted the parse would fail open --
## silently reporting "already absent" and skipping the unbind, which is the worst
## possible failure for a security control.
is_bound() {
  local guid
  guid=$(space_guid "$1")
  [ -n "${guid}" ] || return 1
  cf curl "/v3/security_groups/${group_guid}" 2>/dev/null \
    | jq -e --arg g "${guid}" --arg l "$2" \
        '(.relationships[$l + "_spaces"].data // []) | any(.guid == $g)' >/dev/null
}

echo "Egress security groups for '${CF_SPACE}' ..."

## 1. The proxy serving this space must actually be running. EGRESS_SPACES expresses
## intent; this confirms reality. Without it, a variable edit alone could strip a space's
## egress before its proxy had been built.
proxy_app="${PROJECT}-proxy-${CF_SPACE}"
egress_space_guid=$(cf curl "/v3/spaces?names=${EGRESS_SPACE}&organization_guids=$(cf curl "/v3/organizations?names=${CF_ORG}" 2>/dev/null | jq -r '.resources[0].guid // empty')" 2>/dev/null | jq -r '.resources[0].guid // empty')
proxy_state=$(cf curl "/v3/apps?names=${proxy_app}&space_guids=${egress_space_guid}" 2>/dev/null | jq -r '.resources[0].state // empty')

if [ "${proxy_state}" != "STARTED" ]; then
  echo "  ${CF_SPACE}/running: ${proxy_app} is '${proxy_state:-absent}', not STARTED;"
  echo "                       leaving ${GROUP} in place"
  exit 0
fi

## 2. Only lock down an application space once its application is actually using the
## proxy. Removing public egress from a space whose app has no proxy credentials would
## cut off its outbound traffic with nothing to replace it.
## Looked up through the API rather than `cf app --guid`, which depends on whichever
## space happens to be targeted and fails silently when it is the wrong one.
org_guid=$(cf curl "/v3/organizations?names=${CF_ORG}" 2>/dev/null | jq -r '.resources[0].guid // empty')
space_guid=$(cf curl "/v3/spaces?names=${CF_SPACE}&organization_guids=${org_guid}" 2>/dev/null | jq -r '.resources[0].guid // empty')
app_guid=$(cf curl "/v3/apps?names=${CLIENT_APP}&space_guids=${space_guid}" 2>/dev/null | jq -r '.resources[0].guid // empty')

if [ -z "${app_guid}" ]; then
  echo "  ${CF_SPACE}/running: ${CLIENT_APP} not found; leaving ${GROUP} in place"
  exit 0
fi

## Any service tagged egress-proxy, rather than a specific client's service name --
## a second client must not be missed because the name was hardcoded.
bound_egress=$(cf curl "/v3/service_credential_bindings?app_guids=${app_guid}&include=service_instance" 2>/dev/null \
  | jq -r '[.included.service_instances[]? | select(any(.tags[]?; . == "egress-proxy")) | .name] | join(" ")')

if [ -z "${bound_egress}" ]; then
  echo "  ${CF_SPACE}/running: ${CLIENT_APP} is not bound to an egress credential service;"
  echo "                       leaving ${GROUP} in place"
  exit 0
fi
echo "  ${CF_SPACE}/running: ${CLIENT_APP} is proxied via ${bound_egress}"

## 3. The application is proxied, so the space no longer needs public egress.
if is_bound "${CF_SPACE}" running; then
  echo "  ${CF_SPACE}/running: removing ${GROUP} (${CLIENT_APP} is proxied)"
  cf unbind-security-group "${GROUP}" "${CF_ORG}" "${CF_SPACE}" --lifecycle running || exit 1
  echo "  NOTE: running applications keep their existing rules until restarted."
else
  echo "  ${CF_SPACE}/running: ${GROUP} already absent"
fi

## 4. Keep the proxy's own space able to reach the internet.
##
## Runs last and never fails the deploy. This is a prerequisite that should already be
## satisfied by the documented space setup; if it is not, the right outcome is a loud
## warning, not a red deploy for an application that pushed successfully.
for lifecycle in running staging; do
  if is_bound "${EGRESS_SPACE}" "${lifecycle}"; then
    echo "  ${EGRESS_SPACE}/${lifecycle}: ${GROUP} already bound"
  elif cf bind-security-group "${GROUP}" "${CF_ORG}" --space "${EGRESS_SPACE}" --lifecycle "${lifecycle}" >/dev/null 2>&1; then
    echo "  ${EGRESS_SPACE}/${lifecycle}: bound ${GROUP}"
  else
    echo "  WARNING: ${EGRESS_SPACE}/${lifecycle}: could not bind ${GROUP}."
    echo "           The proxy may be unable to reach the internet. See"
    echo "           terraform/egress/README.md prerequisites."
  fi
done

echo "Egress security groups for '${CF_SPACE}' ... done"
