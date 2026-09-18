## The controlled egress proxy, from GSA-TTS, pinned to a release tag.
##
## One application per environment, all in the shared egress space, so changes can be
## rolled out and tested per environment without touching production.
##
## Each entry in client_configuration gets its own credentials and its own ACL. The
## credentials are not yet wired to any application -- that is the next step.
module "egress_proxy" {
  source = "github.com/GSA-TTS/cg-egress-proxy?ref=v1.1.1"

  count = local.enabled ? 1 : 0

  cf_org_name = var.cloudgov_organization

  cf_egress_space = {
    id   = data.cloudfoundry_space.egress[0].id
    name = data.cloudfoundry_space.egress[0].name
  }

  ## digital-gov-proxy-<workspace>, matching this project's naming.
  ##
  ## route_host is set explicitly. Left to the module it would be derived from the org
  ## and space names, giving a 61-character hostname against a 63-character limit.
  name       = format(local.name_pattern, "proxy")
  route_host = format(local.name_pattern, "proxy")

  instances          = local.instances
  credential_version = local.credential_version

  ## Per-client ACLs: the shared base lists plus anything specific to that client.
  client_configuration = {
    for client_name, client in local.clients : client_name => {
      allowlist = concat(local.base_allowlist, try(client.allowlist, []))
      denylist  = concat(local.base_denylist, try(client.denylist, []))
      ports     = try(client.ports, [443])
    }
  }
}
