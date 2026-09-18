variable "cloudgov_organization" {
  description = "The organization for the cloud.gov account."
  type        = string
  sensitive   = true
}

variable "cloudgov_password" {
  description = "The password for the cloud.gov account."
  type        = string
  sensitive   = true
}

variable "cloudgov_username" {
  description = "The username for the cloudfoundry account."
  type        = string
  sensitive   = true
}
