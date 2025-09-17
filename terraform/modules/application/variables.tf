variable "additional_environmental_variables" {
  description = "Additional environmental variables for the application Useful for dynamic information, like Terraform generated variables."
  type = map(string)
  default = {}
}

variable "cloudfoundry" {
  description = "Cloudfoundry settings."
  type = object(
    {
      domain_external = object(
        {
          domain = string
          id = string
          internal = bool
          name = string
          org = string
          sub_domain = string
        }
      )
      domain_internal = object(
        {
          domain = string
          id = string
          internal = bool
          name = string
          org = string
          sub_domain = string
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
      organization = object(
        {
          annotations = map(string)
          id = string
          labels = map(string)
          name = string
        }
      )
      services = map(
        object(
          {
            id = string
            name = string
            service_broker_guid = string
            service_broker_name = string
            service_plans = map(string)
            space = string
          }
        )
      )
      space = object(
        {
          annotations = map(string)
          id = string
          labels = map(string)
          name = string
          org = string
          org_name = string
          quota = string
        }
      )
    }
  )
}

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
          port         = optional(number, -1)
          public_route = optional(bool, false)
          services_external = optional(list(string), [])
          space        = optional(string ,null)
          source       = optional(string, null)
          stopped       = optional(bool, false)
          templates    = optional(list(map(string)), [])
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
        object({
          enable_ssh = optional(bool, false)
          instances  = optional(number, 1)
          memory     = optional(number, 96)
          port       = optional(number, 61443)
        })
      ), {}
    )
    external_domain = optional(string, "app.cloud.gov")
    internal_domain = optional(string, "apps.internal")
    name_pattern    = string
    organization    = optional(string, "gsa-digitalgov-prototyping")
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

variable "secrets" {
  description = "Sensitive credentials to be used to set application environmental variables."
  type = map(string)
  default = {}
}

variable "services" {
  description = "Services generated from the service module."
  type = object(
    {
      instance = map(
        object(
          {
            annotations = optional(string, null)
            id = optional(string, null)
            json_params = optional(string, null)
            labels = optional(map(string), {})
            name = optional(string, null)
            recursive_delete = optional(bool, null)
            replace_on_params_change = optional(bool, false)
            replace_on_service_plan_change = optional(bool, false)
            service_plan = optional(string, null)
            space = optional(string, null)
            tags = optional(list(string), null)
          }
        )
      )
      user_provided = map(
        object(
          {
            annotations = optional(string, null)
            id = optional(string, null)
            json_params = optional(string, null)
            labels = optional(map(string), {})
            name = optional(string, null)
            recursive_delete = optional(bool, null)
            replace_on_params_change = optional(bool, false)
            replace_on_service_plan_change = optional(bool, false)
            service_plan = optional(string, null)
            space = optional(string, null)
            tags = optional(list(string), null)
          }
        )
      )
      service_key = map(
        object(
          {
            name = optional(string, null)
            service_instance = optional(string, null)
            params = optional(map(string), null)
            params_json = optional(string, null)
            credentials = optional(map(string), {})
          }
        )
      )
    }
  )
  default = null
}