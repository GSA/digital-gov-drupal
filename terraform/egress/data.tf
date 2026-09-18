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
