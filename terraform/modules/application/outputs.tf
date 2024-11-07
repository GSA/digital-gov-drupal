output "apps" {
  description = "A `map` of [cloudfoundry_app](https://registry.terraform.io/providers/cloudfoundry-community/cloudfoundry/latest/docs/resources/app) resource outputs. The key is the app name."
  value = merge(
    flatten([
      for key, value in try(var.env.apps, {}) : {
        "${key}" = try(cloudfoundry_app.this[key], null)
      }
    ])
  ...)
}

output "external_endpoints" {
  description = "A map of external URL's (app.cloud.gov) to used to reach an application. The key is the app name."
  sensitive = true
  value = merge(
    flatten([
      for key, value in try(var.env.apps, {}) : {
        "${key}" = try(cloudfoundry_route.external[key].endpoint, null)
      } if value.public_route 
  ])
  ...)
}

output "internal_endpoints" {
  description = "A map of internal URL's (apps.internal) to used to reach an application. The key is the app name."
  sensitive = true
  value = merge(
    flatten([
      for key, value in try(var.env.apps, {}) : {
        "${key}" = try(cloudfoundry_route.internal[key].endpoint, null)
      } if !value.public_route 
  ])
  ...)
}