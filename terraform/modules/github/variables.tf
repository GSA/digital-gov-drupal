variable "env" {
  description = "The settings object for this environment."
  type = object({
    api_url               = optional(string, "https://api.fr.cloud.gov")
    apps = optional(
      map(
        object({
          allow_egress         = optional(bool, true)
          buildpacks           = list(string)
          command              = optional(string, "entrypoint.sh")
          disk_quota           = optional(number, 1024)
          enable_ssh           = optional(bool, false)
          environment          = optional(map(string), {})
          health_check_timeout = optional(number, 180)
          health_check_type    = optional(string, "port")
          instances            = optional(number, 1)
          labels = optional(map(string), {})
          memory = optional(number, 96)
          network_policies = optional(map(number),{})
          port         = optional(number, 80)
          public_route = optional(bool, false)
          source       = optional(string, null)
          templates    = list(map(string))
        })
      ), {}
    )
    bootstrap_workspace = optional(string, "bootstrap")
    defaults = object(
      {
        disk_quota           = optional(number, 2048)
        enable_ssh           = optional(bool, true)
        health_check_timeout = optional(number, 60)
        health_check_type    = optional(string, "port")
        instances            = optional(number, 1)
        memory               = optional(number, 64)
        port                 = optional(number, 8080)
        stack                = optional(string, "cflinuxfs4")
        stopped              = optional(bool, false)
        strategy             = optional(string, "none")
        timeout              = optional(number, 300)
      }
    )
    external_applications = optional(
      map(
        object(
          {
            name       = string
            environement = string
            port       = optional(number, 61443)
          }
        )
      ),{}
    )
    external_domain = optional(string, "app.cloud.gov")
    internal_domain = optional(string, "apps.internal")
    name_pattern    = string
    organization    = optional(string, "gsa-tts-usagov")
    passwords = optional(
      map(
        object(
          {
            experation_days = optional(number, 0)
            length = number
            lower = optional(bool, false)
            min_lower = optional(number, 0)
            min_numeric = optional(number, 0)
            min_special = optional(number, 0)
            min_upper = optional(number, 0)
            numeric = optional(bool, true)
            override_special = optional(string, "!@#$%&*()-_=+[]{}<>:?")
            special = optional(bool, true)
            upper = optional(bool, true)
          }
        )
      ), {}
    )
    project = string
    secrets = optional(
      map(
        object(
          {
            encrypted = bool
            key = string
          }
        )
      ), {}
    )
    services = optional(
      map(
        object(
          {
            applications = optional(list(string), [])
            environement = optional(string, "dev")
            service_key  = optional(bool, true)
            service_plan = optional(string, "basic")
            service_type = optional(string, "s3")
            tags         = optional(list(string), [])
          }
        )
      ), {}
    )
    space = string
  })
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

variable "repository" {
  description = "The GitHub respository."
  type = string
}

variable "secrets" {
  default = {}
  description = "Secrets to create in the respository."
  type = map(string)
}

variable "variables" {
  default = {}
  description = "Variables to create in the respository."
  type = map(string)
}
