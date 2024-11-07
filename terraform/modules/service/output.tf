output "results" {
  value = {
    instance = try(cloudfoundry_service_instance.this, null)
    user_provided = try(cloudfoundry_user_provided_service.this, null)
    service_key = try(cloudfoundry_service_key.this, {})
  }
}
