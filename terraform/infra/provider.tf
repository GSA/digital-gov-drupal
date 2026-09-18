terraform {
  required_providers {
    ## This configuration runs entirely on the community provider. The egress proxy
    ## needs the official cloudfoundry/cloudfoundry provider, and the two cannot share
    ## a root module -- Terraform resolves providers by type and both have the type
    ## "cloudfoundry". That work lives in ../egress instead.
    cloudfoundry = {
      source  = "cloudfoundry-community/cloudfoundry"
      version = "~> 0.5"
    }
  }
  required_version = "> 1.7"
}

terraform {
  backend "pg" { }
}

provider "cloudfoundry" {
  api_url   = local.env.api_url
  user      = var.cloudgov_username
  password  = var.cloudgov_password
}
