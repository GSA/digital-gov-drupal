terraform {
  required_providers {
    cloudfoundry = {
      source  = "cloudfoundry-community/cloudfoundry"
      version = "~> 0.51.0"
    }
  }
  required_version = "> 1.7"
}
