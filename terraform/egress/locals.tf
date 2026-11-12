locals {

  ## Kept in step with ../infra/locals.tf.
  project      = "digital-gov"
  api_url      = "https://api.fr.cloud.gov"
  name_pattern = "${local.project}-%s-${terraform.workspace}"

  ## Workspaces that the production instance count applies to.
  production_workspaces = ["prod"]

  ## Environments the proxy is deployed for, from the EGRESS_SPACES repository variable
  ## rather than hardcoded here -- switching an environment on should not require a pull
  ## request. Applying in a workspace that is not listed is a safe no-op.
  ##
  ## One variable, not two: the security-group lockdown reads the same one, so a space
  ## can never be locked down without a proxy to replace its egress.
  ##
  ## The filter drops empty strings so that an unset variable yields [] rather than [""].
  enabled_workspaces = [
    for workspace in split(" ", trimspace(var.egress_spaces)) : workspace
    if workspace != ""
  ]

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
    "*.newrelic.com",

    ## scripts/bootstrap.sh downloads the AWS CLI on every container start -- it runs at
    ## pre-start, not staging. This is a CloudFront host, so it is NOT covered by the AWS
    ## S3 Gateway ranges in trusted_local_networks_egress. Without it there is no `aws`
    ## binary and the static site build dies with exit 127.
    "awscli.amazonaws.com"
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

    ## The Drupal CMS. Uses the proxy for the New Relic PHP daemon and, via
    ## http_client_config in settings.cloudgov.php, for Drupal's own server-side HTTP
    ## (GSA Auth and media oEmbed). Its S3 traffic goes direct -- see the `no` list
    ## in that file.
    ##
    ## `app` is the Cloud Foundry application name, which the network policy and the
    ## credential service are attached to. It is looked up, not managed -- this
    ## application is deployed from manifest.yml, not Terraform.
    ## bind_service is not set here: the CMS is deployed from manifest.yml, which binds
    ## the credential service through its EGRESS_SERVICE_BINDING placeholder. Clients
    ## deployed by Terraform set bind_service = true instead -- see main.tf.
    cms = {
      app = format(local.name_pattern, "drupal")

      ## Drupal's own server-side HTTP, enabled by http_client_config in
      ## settings.cloudgov.php. These are client-specific rather than base entries --
      ## no other client needs them.
      allowlist = [
        ## GSA Auth (openid_connect). The OIDC plugin builds its authorize, token and
        ## userinfo endpoints directly from `okta_domain`, so the host listed here must
        ## match that config exactly -- see OpenIDConnectOktaClient::getEndpoints().
        ##
        ##   dev / staging  config/sync/openid_connect.client.gsa_auth.yml
        ##   production     config/production/config_split.patch...gsa_auth.yml
        ##
        ## Without the right host the code-for-token exchange is refused by the proxy
        ## and SSO login breaks. secureauth.gsa.gov is deliberately absent: it is the
        ## SAML-era IdP and appears nowhere in the OIDC configuration.
        "auth-preprod.gsa.gov",
        "auth.gsa.gov",

        ## Media oEmbed: the provider list, then YouTube, which is the only provider
        ## enabled in media.type.video.
        "oembed.com",
        "www.youtube.com",
        "i.ytimg.com",
      ]
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
