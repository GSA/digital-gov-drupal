locals {
  additional_variables = {
    CF_USER     = data.cloudfoundry_service_key.pipeline.credentials.username
    CF_PASSWORD = data.cloudfoundry_service_key.pipeline.credentials.password
  }
  ## Merging of the various credentials and environmental variables.
  service_secrets = merge(
    flatten(
      [
        for service_key, service_value in try(local.env.services, {}) : [
          for key, value in try(module.services.results.service_key[service_key].credentials, {}) : {
            "${service_key}-${nonsensitive(key)}" = nonsensitive(value)
          }
        ] if try(module.services.results.service_key[service_key].credentials, null) != null
      ]
    )
  ...)

  random_secrets = merge(
    flatten(
      [
        for random_key, random_value in try(module.random.results, {}) : {
          "${random_key}" = random_value.sha256
        }
      ]
    )
  ...)

  local_secrets = merge(
    flatten(
      [
        for key, value in try(local.env.secrets, {}) : {
          "${value.key}" = value.value
        } if can(value.value)
      ]
    )
  ...)

  secrets = merge(local.service_secrets, local.local_secrets, local.random_secrets)

  variables = merge(
    flatten(
      [
        for key, value in try(local.env.variables, {}) : {
          "${value.key}" = value.value
        } if can(value.value)
      ]
    )
  ...)
}

module "random" {
  source    = "../modules/random"
  names     = [ "dev" ]
  passwords = local.env.passwords
}

## The instanced services (i.e. RDS, S3, etc.) get created first.
## This allows their credentials to be injected into "user-provided" services (JSON blobs), if needed.
module "services" {
  source = "../modules/service"

  cloudfoundry                = local.cloudfoundry
  env                         = local.env
  skip_user_provided_services = true
}

# module "secrets" {
#   source = "../modules/service"

#   cloudfoundry           = local.cloudfoundry
#   env                    = local.env
#   skip_service_instances = true 
#   secrets                = local.secrets
# }

module "applications" {
  #for_each = local.cloudfoundry.spaces
  source = "../modules/application"

  #additional_service_bindings = { "pipeline" = data.cloudfoundry_service_instance.pipeline.id }
  additional_environmental_variables = local.additional_variables
  cloudfoundry = local.cloudfoundry
  env = merge(local.envs.all, local.envs.bootstrap, local.envs[local.production_space])
  secrets = local.secrets
  services = module.services.results
}

module "github" {
  source = "../modules/github"

  env = local.env
  github_organization = var.github_organization
  github_token = var.github_token
  repository = local.repository
  secrets = merge(local.secrets, local.additional_variables)
  variables = local.variables
}
