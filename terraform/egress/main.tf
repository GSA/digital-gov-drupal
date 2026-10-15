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
    for client_name, client in local.active_clients : client_name => {
      allowlist = concat(local.base_allowlist, try(client.allowlist, []))
      denylist  = concat(local.base_denylist, try(client.denylist, []))
      ports     = try(client.ports, [443])
    }
  }
}

## Each client's credentials, delivered as a user-provided service in the application's
## own space. One service per client, so a client only ever sees its own credentials.
##
## Terraform creates the service; manifest.yml binds it. That split matches every other
## service this application uses (mysql, secrets, static, storage) -- see the
## EGRESS_SERVICE_BINDING placeholder in manifest.yml.
##
## The payload uses `proxy_uri` rather than the module's own json_credentials output,
## whose shape changes from flat to nested once a second client exists. A fixed key
## means adding the log shipper later cannot silently break the CMS.
resource "cloudfoundry_service_instance" "egress_credentials" {
  for_each = local.active_clients

  name  = format(local.name_pattern, "egress-${each.key}")
  space = data.cloudfoundry_space.app[0].id
  type  = "user-provided"

  ## Applications locate this by tag, not by name.
  tags = [local.credential_tag, terraform.workspace]

  credentials = jsonencode({
    proxy_uri  = module.egress_proxy[0].https_proxy[each.key]
    domain     = module.egress_proxy[0].domain
    https_port = module.egress_proxy[0].https_port
  })
}

## Bind the credentials for clients Terraform is asked to bind.
##
## Two binding paths exist because applications reach this space two ways:
##
##   - deployed from manifest.yml (the CMS) -- bound by the EGRESS_SERVICE_BINDING
##     placeholder there, matching how mysql, secrets, static and storage are bound.
##     Leave bind_service unset for these.
##
##   - deployed by Terraform (the WAF, the bastions, a future log shipper) -- their
##     bindings live in terraform/infra, which cannot reference a service created here
##     because it is a separate configuration with separate state. Set bind_service = true
##     and the binding is made from this configuration instead, which has both the
##     application and the service to hand.
##
## Setting bind_service on an application that is also bound by manifest.yml would create
## two owners of one binding. Use exactly one path per client.
resource "cloudfoundry_service_credential_binding" "egress" {
  for_each = {
    for client_name, client in local.active_clients : client_name => client
    if try(client.bind_service, false)
  }

  type             = "app"
  name             = "egress-${each.key}"
  app              = data.cloudfoundry_app.client[each.key].id
  service_instance = cloudfoundry_service_instance.egress_credentials[each.key].id
}

## Container-to-container access from each client to the proxy. Without this the
## credentials are useless -- the client cannot reach the proxy's port at all.
##
## Port 61443 implicitly terminates TLS at the platform, which is why the credential
## URI uses https://.
resource "cloudfoundry_network_policy" "egress" {
  for_each = local.active_clients

  ## One resource per client rather than one resource holding every policy: removing a
  ## client then removes exactly its own policy, and the schema requires a non-empty
  ## list, which a shared resource would violate in a workspace with no clients.
  policies = [{
    source_app      = data.cloudfoundry_app.client[each.key].id
    destination_app = module.egress_proxy[0].app_id
    port            = local.mtls_port
    protocol        = "tcp"
  }]
}
