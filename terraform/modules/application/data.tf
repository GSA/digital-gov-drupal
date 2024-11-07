locals {

  ## Create a single list of external service names. Multiple applications
  ## could reference the same service, but the GUID only needs to be looked up once.
  services_external = toset(
    compact(
      distinct(
        flatten(
          [
            for value in try(var.env.apps, {}) : [
              try(value.services_external, [])
            ]
          ]
        )
      )
    )
  )
}

## Lookup up service instance GUID's for existing services.
## These can be externally deployed services or services deployed from different code sources.
## The GUID can then be refrenced by data.cloudfoundry_service_instance.this["service-name"].id
data "cloudfoundry_service_instance" "this" {
  for_each = try(local.services_external, [])
  name_or_id  = each.value
  space       = try(var.cloudfoundry.space.id, null)
}