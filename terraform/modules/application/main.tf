locals {
  domains = merge(
    merge(
      flatten([
        for key, value in try(var.env.apps, {}) : {
          "${key}_internal_endpoint" = try(value.public_route, false) ? "${format(var.env.name_pattern, key)}.${var.env.external_domain}" : "${format(var.env.name_pattern, key)}.${var.env.internal_domain}"
        }
      ])
    ...),
     merge(
      flatten([
        for key, value in try(var.env.external_applications, {}) : {
          "${key}_internal_endpoint" = try(value.public_route, false) ? "${format(var.env.name_pattern, key)}.${var.env.external_domain}" : "${format(var.env.name_pattern, key)}.${var.env.internal_domain}"
        }
      ])
    ...)
  )

  service_keys = merge(
    flatten([
      for service_key, service_value in try(var.env.services, {}) : [
        for key, value in try(var.services.service_key[service_key].credentials, {}) : {
          "${service_key}_${key}" = value
        } if try(var.services.service_key[service_key].credentials, null) != null
       ] 
    ])
  ...)

  service_bindings = merge(
    flatten(
      [ 
        for key, value in try(var.env.services, {}) : {
          #svc_value.name => svc_value
          "${key}" = value
        }
      ]
    )
  ...)
}

resource "local_sensitive_file" "this" {
  for_each = { for key, value in flatten([
    for key, value in try(var.env.apps, {}) : [
        for kt, vt in try(value.templates, []) : {
          name = basename(vt.destination)
          source = vt.source
          destination = vt.destination
          vars = value.environment
        }
      ]
    ]) : basename(value.destination) => value
  }
  
  content   = templatefile(
    each.value.source,
    merge(
      var.secrets,
      local.domains,
      local.service_keys,
      each.value.vars
    )
  )
  filename  = each.value.destination
}

data "archive_file" "this" {
  for_each = { 
    for key, value in try(var.env.apps, {}) : key => value
    if try(value.source, null) != null && !endswith(try(value.source, ""), ".zip")
  }
  
  type  = "zip"
  source_dir =  each.value.source
  output_path = "/tmp/${var.env.project}-${each.key}-${terraform.workspace}.zip"

  depends_on = [
    local_sensitive_file.this
  ]
}

resource "cloudfoundry_app" "this" {
  for_each = {
    for key, value in try(var.env.apps, {}) : key => value
  }
  
  buildpack = try(each.value.buildpack, null)
  buildpacks = try(each.value.buildpacks, null)
  command = try(each.value.command, null)
  disk_quota = try(each.value.disk_quota, try(var.env.defaults.disk_quota, 1024))
  docker_credentials = try(each.value.docker_credentials, null)
  docker_image = try(each.value.docker_image, null)
  enable_ssh = try(each.value.enable_ssh, try(var.env.defaults.enable_ssh, true))
  environment = merge(try(each.value.environment, {}), try(var.additional_environmental_variables, {}))
  health_check_http_endpoint = try(each.value.health_check_http_endpoint, try(var.env.defaults.health_check_http_endpoint, null))
  health_check_invocation_timeout = try(each.value.health_check_invocation_timeout, try(var.env.defaults.health_check_invocation_timeout, 5))
  health_check_timeout = try(each.value.health_check_timeout, try(var.env.defaults.health_check_timeout, 180))
  health_check_type = try(each.value.health_check_type, try(var.env.defaults.health_check_type, "port"))
  instances = try(each.value.instances, try(var.env.defaults.instances, 1))
  labels = try(each.value.labels, {})
  memory = try(each.value.memory, try(var.env.defaults.memory, 64))
  name = format(var.env.name_pattern, each.key)
  path = endswith(try(each.value.source, ""), ".zip") ? each.value.source : "/tmp/${var.env.project}-${each.key}-${terraform.workspace}.zip"
  source_code_hash = endswith(try(each.value.source, ""), ".zip") ? filebase64sha256(each.value.source) : data.archive_file.this[each.key].output_base64sha256
  space = var.cloudfoundry.space.id
  stack = try(each.value.stack, try(var.env.defaults.stack, "cflinux4"))
  stopped = try(each.value.stopped, try(var.env.defaults.stopped, false))
  strategy = try(each.value.strategy, try(var.env.defaults.strategy, "none"))
  timeout = try(each.value.timeout, try(var.env.defaults.timeout, 60))

  dynamic "service_binding" {
    for_each = { 
      for svc_key, svc_value in try(var.env.services, {}) : svc_key => svc_value
      if contains(svc_value.applications, each.key) && svc_value.service_type != "user-provided"
    }
    content {
      service_instance = var.services.instance[service_binding.key].id
      params_json = try(var.env.services[service_binding.key].params_json, null)
      params = try(var.env.services[service_binding.key].params, {})
    }
  }

  dynamic "service_binding" {
    for_each = { 
      for svc_key, svc_value in try(var.env.services, {}) : svc_key => svc_value
      if contains(svc_value.applications, each.key) &&
         svc_value.service_type == "user-provided"
    }
    content {
      service_instance = var.services.user_provided[service_binding.key].id
      params_json = try(var.env.services[service_binding.key].params_json, null)
      params = try(var.env.services[service_binding.key].params, {})
    }
  }

  ## Bind any external services, not deployed by the root code calling this module.
  dynamic "service_binding" {
    for_each = try(local.services_external, [])
    content {
      service_instance = data.cloudfoundry_service_instance.this[service_binding.value].id
      params_json = try(var.env.services[service_binding.value].params_json, null)
      params = try(var.env.services[service_binding.value].params, {})
    }
  }

  depends_on = [
    data.archive_file.this,
  ]
}
