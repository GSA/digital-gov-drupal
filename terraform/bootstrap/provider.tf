terraform {
  required_providers {
    cloudfoundry = {
      source = "cloudfoundry-community/cloudfoundry"
      version = "~> 0.5"
    }
  }
  required_version = "> 1.7"
}

provider "cloudfoundry" {
  api_url   = local.env.api_url
  user      = var.cloudgov_username
  password  = var.cloudgov_password
}

# Configure the GitHub Provider
provider "github" {
  owner = var.github_organization
  token = var.github_token
}