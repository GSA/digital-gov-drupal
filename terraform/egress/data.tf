data "cloudfoundry_org" "this" {
  name = var.cloudgov_organization
}

## The space holding public_networks_egress. Created once outside this configuration
## (it needs OrgManager), shared by every environment, so it is read not managed.
data "cloudfoundry_space" "egress" {
  count = local.enabled ? 1 : 0

  name = local.egress_space
  org  = data.cloudfoundry_org.this.id
}

## The application space for this workspace -- where the client applications run and
## where their credential services are created.
data "cloudfoundry_space" "app" {
  count = local.enabled ? 1 : 0

  name = terraform.workspace
  org  = data.cloudfoundry_org.this.id
}

## The client applications. Looked up rather than managed: digital-gov-drupal is
## deployed from manifest.yml, and future clients may equally not be Terraform-managed.
## See egress-plan.md D10.
##
## NOTE: these must already exist. The egress configuration runs during deploy-infra,
## before deploy-app, so a brand-new space needs one application deploy before the
## proxy can be wired to it.
data "cloudfoundry_app" "client" {
  for_each = local.active_clients

  name       = each.value.app
  space_name = terraform.workspace
  org_name   = var.cloudgov_organization
}
