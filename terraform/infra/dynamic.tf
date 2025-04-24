locals {

  ## Map of service instances and secrets merged together.
  services = {
    instance = merge(
      module.services.results.instance,
      module.secrets.results.instance
    )
    user_provided = merge(
      module.services.results.user_provided,
      module.secrets.results.user_provided
    )
    service_key = merge(
      module.services.results.service_key,
      module.secrets.results.service_key
    )
  }

  ## Merging of the various credentials and environmental variables.
  secrets = merge(
    merge(
      flatten([
        for app in try(local.env.services, []) : [
          for key, value in try(module.services.results.service_key[app.name].credentials, {}) : {
            "${app.name}_${key}" = value
          }
        ] if try(module.services.results.service_key[app.name].credentials, null) != null
      ])
    ...),
    merge(
      flatten([
        for key, value in try(module.random.results, {}) : {
          "${key}" = value.result
        }
      ])
    ...),
    {
      gsa_auth_key              = var.gsa_auth_key
      newrelic_key              = var.newrelic_key
    }
  )

  ## List of the workspaces defined in the configuration above.
  workspaces = flatten([
    for key, value in local.envs : [
      key
    ]
  ])
}
