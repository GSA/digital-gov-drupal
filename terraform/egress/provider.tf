terraform {
  required_providers {

    ## The official Cloud Foundry provider. This configuration is deliberately kept
    ## separate from ../infra, which runs on cloudfoundry-community/cloudfoundry.
    ##
    ## The two cannot live in one root module: Terraform resolves provider references
    ## by TYPE, and both providers have the type "cloudfoundry", so a second local name
    ## does not disambiguate them. See egress-plan.md section 1.11.
    cloudfoundry = {
      source  = "cloudfoundry/cloudfoundry"
      version = "~> 1.18.0"
    }
  }

  ## Required by the cg-egress-proxy module.
  required_version = ">= 1.10"
}

terraform {
  backend "pg" {

    ## MUST differ from ../infra. The pg backend keys state by workspace name within
    ## one schema+table, so sharing the default "terraform_remote_state" schema would
    ## make this configuration's "dev" state collide with the infra "dev" state.
    schema_name = "terraform_remote_state_egress"
  }
}

provider "cloudfoundry" {
  api_url  = local.api_url
  user     = var.cloudgov_username
  password = var.cloudgov_password
}
