locals {
  credentials = merge(
    flatten([
        for key, value in try(var.env.services,{}) : {
          "${key}" = {
            applications = value.applications
            service_type = value.service_type
            tags = value.tags
            credentials = merge(
              [
                for name in try(value.credentials, {}) : {
                  name = try(var.secrets[name], null)
                }
              ]
            ...)
          }
       } if !var.skip_user_provided_services &&
            value.service_type == "user-provided"
    ])
  ...)
}


resource "cloudfoundry_service_key" "this" {
  for_each = {
    for key, value in try(var.env.services, {}) : key => value
    if !var.skip_service_instances &&
       value.service_type != "user-provided" &&
       try(value.service_key, false)
  }
  
  name = format("%s-%s-%s", format(var.env.name_pattern, each.key), each.key, "svckey")
  service_instance = cloudfoundry_service_instance.this[each.key].id
}

resource "cloudfoundry_service_instance" "this" {
  for_each = {
    for key, value in try(var.env.services, {}) : key => value
    if !var.skip_service_instances &&
       value.service_type != "user-provided"
  }

  name                            = format(var.env.name_pattern, each.key)
  json_params                     = try(each.value.json_params, null)
  replace_on_params_change        = try(each.value.replace_on_service_plan_change, false)
  replace_on_service_plan_change  = try(each.value.replace_on_service_plan_change, false)
  space                           = var.cloudfoundry.space.id
  service_plan                    = var.cloudfoundry.services[each.key].service_plans[each.value.service_plan]
  tags                            = try(each.value.tags, [])
}

resource "cloudfoundry_user_provided_service" "this" {
  for_each = {
    for key, value in local.credentials : key => value
  }

  name              = format(var.env.name_pattern, each.key)
  space             = var.cloudfoundry.space.id
  credentials_json  = jsonencode(try(each.value.credentials, {}))
  tags              = try(each.value.tags, [])
}
