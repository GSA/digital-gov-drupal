variable "cloudgov_organization" {
  description = "The organization for the cloud.gov account."
  type        = string
  sensitive   = true
}

variable "cloudgov_production_space" {
  description = "The production space for the cloud.gov project."
  type        = string
  sensitive   = true
}

variable "github_organization" {
  description = "The organization to use with GitHub."
  type = string
  default = "GSA"
}
variable "github_token" {
  description = "The token used authenticate with GitHub."
  type        = string
  sensitive   = true
}

variable "gsa_auth_development_key" {
  description = "The GSA Auth key for development environments."
  type = string
  sensitive = true
}

variable "gsa_auth_production_key" {
  description = "The GSA Auth key for production environments."
  type = string
  sensitive = true
}

variable "mtls_port" {
  description = "The default port to direct traffic to. Envoy proxy listens on 61443 and redirects to 8080, which the application should listen on."
  type        = number
  default     = 61443
}