terraform {
  required_providers {
    ## The community provider. Used by everything in this configuration that
    ## predates the egress proxy work. Do not add new resources against it.
    cloudfoundry = {
      source  = "cloudfoundry-community/cloudfoundry"
      version = "~> 0.5"
    }

    ## The official Cloud Foundry provider, under a second local name so the two
    ## can coexist. Required by the GSA-TTS/cg-egress-proxy module and by
    ## cloudfoundry_security_group_space_bindings, neither of which the community
    ## provider supports. See egress-plan.md section 1.5.
    cloudfoundryv1 = {
      source  = "cloudfoundry/cloudfoundry"
      version = ">= 1.6.0"
    }
  }

  ## Raised from "> 1.7" for the cg-egress-proxy module, which requires "~> 1.10".
  ## Keep in step with OPENTOFU_VERSION in ../bootstrap/locals.tf.
  required_version = ">= 1.10"
}

terraform {
  backend "pg" { }
}

provider "cloudfoundry" {
  api_url   = local.env.api_url
  user      = var.cloudgov_username
  password  = var.cloudgov_password
}

## Same credentials and endpoint as the block above -- both use the UAA password
## grant, so the existing space-deployer service account covers both.
##
## These attributes are set explicitly on purpose. Left empty, this provider falls
## back to CF_* environment variables and then to the CF CLI's config.json in
## CF_HOME. The tf-bastion has a live cf session during pipeline runs, so an empty
## block could silently authenticate as that session's identity instead.
provider "cloudfoundryv1" {
  api_url  = local.env.api_url
  user     = var.cloudgov_username
  password = var.cloudgov_password
}
