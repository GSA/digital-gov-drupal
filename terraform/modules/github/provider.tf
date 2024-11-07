terraform {
  required_providers {
    github = {
      source  = "integrations/github"
      version = "~> 6.0"
    }
  }
  required_version = "> 1.7"
}

# Configure the GitHub Provider
provider "github" {
  owner = var.github_organization
  token = var.github_token
}