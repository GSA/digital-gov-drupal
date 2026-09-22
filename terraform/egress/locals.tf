locals {

  ## Kept in step with ../infra/locals.tf.
  project      = "digital-gov"
  api_url      = "https://api.fr.cloud.gov"
  name_pattern = "${local.project}-%s-${terraform.workspace}"

  ## Workspaces that the production instance count applies to.
  production_workspaces = ["prod"]

  ## Workspaces the proxy is deployed for. This is the switch that turns the feature
  ## on for an environment -- add "staging" and "prod" as the rollout proceeds.
  ## Applying with a workspace that is not listed is a safe no-op.
  enabled_workspaces = ["dev"]

  ## The space holding the public_networks_egress security group, where the proxy
  ## applications run. Shared by every environment and created once, outside this
  ## configuration, so it is read rather than managed here. Named to match USAGov.
  egress_space = "shared-egress"

  ## Hosts every client may reach.
  ##
  ## *.newrelic.com covers gov-collector.newrelic.com (the PHP agent daemon) and
  ## gov-log-api.newrelic.com (the log shipper, when it is ported over).
  ##
  ## S3 is deliberately absent. trusted_local_networks_egress already permits the AWS
  ## S3 Gateway ranges on 443, so bucket traffic goes direct and must never be routed
  ## through the proxy -- doing so would break `aws s3 sync` in scripts/upkeep.
  ## See egress-plan.md section 1.1.
  base_allowlist = [
    "*.newrelic.com"
  ]

  ## Hosts no client may reach, whatever their allowlist says.
  base_denylist = []

  ## One entry per application needing outbound access. Each client gets its own
  ## credentials and its own ACL, so no client can use another's grants.
  ##
  ## Adding an application later is one entry here plus its own proxy configuration.
  ## The client does not need to be Terraform-managed -- digital-gov-drupal is
  ## deployed from manifest.yml. See egress-plan.md D10.
  clients = {

    ## The Drupal CMS. Needs the proxy only for the New Relic PHP daemon; its S3
    ## traffic goes direct.
    ##
    ## `app` is the Cloud Foundry application name, which the network policy and the
    ## credential service are attached to. It is looked up, not managed -- this
    ## application is deployed from manifest.yml, not Terraform.
    cms = {
      app       = format(local.name_pattern, "drupal")
      allowlist = []
    }

    ## Deliberately NOT clients, recorded so the reasoning is not relitigated:
    ##   waf    - only reaches S3 and Drupal over c2c, both already permitted
    ##   backup - database-backup-bastion only reaches S3 and RDS
    ## tf-bastion and the log shipper join later; see egress-plan.md steps 6 and 7.
  }

  ## Proxy instances per environment. Production runs two for availability.
  instances = contains(local.production_workspaces, terraform.workspace) ? 2 : 1

  ## Changing this string rotates every client credential. Deliberate action only:
  ## every client application must be restarted afterwards to pick up the new value.
  ## This is the mechanism that makes credential drift impossible -- an allowlist or
  ## code change cannot silently rotate credentials the way USAGov's scripts can.
  ## See egress-plan.md section 1.7.
  credential_version = "1"

  ## Is the proxy deployed in this workspace?
  enabled = contains(local.enabled_workspaces, terraform.workspace)

  ## Clients, but only when the feature is on -- keeps every for_each below empty in a
  ## workspace that is not being rolled out to.
  active_clients = local.enabled ? local.clients : {}

  ## Tag on each credential service. Applications find their proxy by this tag rather
  ## than by a fixed service name, matching how settings.cloudgov.php locates the
  ## cache service.
  credential_tag = "egress-proxy"

  ## The mTLS port. Cloud Foundry terminates TLS here and forwards to the app's $PORT.
  mtls_port = "61443"
}
