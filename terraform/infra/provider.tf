terraform {
  required_providers {
    cloudfoundry = {
      source  = "cloudfoundry-community/cloudfoundry"
      version = "~> 0.5"
    }
  }
  required_version = "> 1.7"
}

# Temporarily disabled for local validation
# {
#   backend "pg" { }
# }

provider "cloudfoundry" {
  api_url   = local.env.api_url
  user      = var.cloudgov_username
  password  = var.cloudgov_password
}
