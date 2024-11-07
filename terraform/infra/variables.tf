variable "cloudgov_username" {
  description = "The username for the cloudfoundry account."
  type        = string
  sensitive   = true
}

variable "cloudgov_password" {
  description = "The password for the cloud.gov account."
  type        = string
  sensitive   = true
}

variable "terraform_working_dir" {
  description = "Working directory for Terraform."
  type = string
  default = "digital-gov-drupal/terraform"
}

variable "mtls_port" {
  description = "The default port to direct traffic to. Envoy proxy listens on 61443 and redirects to 8080, which the application should listen on."
  type        = number
  default     = 61443
}