variable "egress_spaces" {
  description = <<-EOT
    Space-separated list of environments the egress proxy is enabled for, e.g.
    "dev staging". Supplied from the EGRESS_SPACES repository variable so environments can
    be switched on without a code change. Empty means the feature is off everywhere and
    applying is a no-op.

    The same variable gates the security-group lockdown in cloudgov-deploy-app.yml, so a
    space cannot be locked down without also having a proxy. See README.md.
  EOT
  type        = string
  default     = ""
}

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
