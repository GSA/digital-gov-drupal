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
EGRESS_SERVICE="${PROJECT}-egress-cms-${CF_SPACE}"
CLIENT_APP="${PROJECT}-${APP_NAME}-${CF_SPACE}"

for required in CF_ORG CF_SPACE PROJECT APP_NAME; do
  if [ -z "${!required}" ]; then
    echo "ERROR: ${required} must be set"
    exit 1
  fi
done

## Is $GROUP bound to $1 for lifecycle $2?
is_bound() {
  cf security-groups 2>/dev/null \
    | awk -v g="${GROUP}" -v o="${CF_ORG}" -v s="$1" -v l="$2" \
          '$1==g && $2==o && $3==s && $4==l {found=1} END {exit !found}'
}

echo "Egress security groups for '${CF_SPACE}' ..."

## 1. The proxy's own space must always reach the internet.
for lifecycle in running staging; do
  if is_bound "${EGRESS_SPACE}" "${lifecycle}"; then
    echo "  ${EGRESS_SPACE}/${lifecycle}: ${GROUP} already bound"
  else
    echo "  ${EGRESS_SPACE}/${lifecycle}: binding ${GROUP}"
    cf bind-security-group "${GROUP}" "${CF_ORG}" --space "${EGRESS_SPACE}" --lifecycle "${lifecycle}" || exit 1
  fi
done

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

bound_services=$(cf curl "/v3/service_credential_bindings?app_guids=${app_guid}&include=service_instance" 2>/dev/null \
  | jq -r '[.included.service_instances[]?.name] | join(" ")')

case " ${bound_services} " in
  *" ${EGRESS_SERVICE} "*)
    ;;
  *)
    echo "  ${CF_SPACE}/running: ${CLIENT_APP} is not bound to ${EGRESS_SERVICE};"
    echo "                       leaving ${GROUP} in place"
    exit 0
    ;;
esac

## 3. The application is proxied, so the space no longer needs public egress.
if is_bound "${CF_SPACE}" running; then
  echo "  ${CF_SPACE}/running: removing ${GROUP} (${CLIENT_APP} is proxied)"
  cf unbind-security-group "${GROUP}" "${CF_ORG}" "${CF_SPACE}" --lifecycle running || exit 1
  echo "  NOTE: running applications keep their existing rules until restarted."
else
  echo "  ${CF_SPACE}/running: ${GROUP} already absent"
fi

echo "Egress security groups for '${CF_SPACE}' ... done"
