locals {
  cloudfoundry = {
    external_applications = try(data.cloudfoundry_app.external_applications, null)
    domain_external = try(data.cloudfoundry_domain.external, null)
    domain_internal = try(data.cloudfoundry_domain.internal, null)
    organization = try(data.cloudfoundry_org.this, null)
    services = try(data.cloudfoundry_service.this, null)
    space = try(data.cloudfoundry_space.this, null)
  }
}

data "cloudfoundry_app" "external_applications" {
  for_each = {
    for key, value in try(local.env.external_applications, []) : value.name => value
    if try(value.deployed, false) && 
       try(data.cloudfoundry_space.this.id, null) != null
  }
  name_or_id  = format(local.env.name_pattern, each.key)
  space       = try(data.cloudfoundry_space.this.id, null)
} 

data "cloudfoundry_domain" "external" {
  //domain      = "${split(".", local.env.external_domain)[1]}.${split(".", local.env.external_domain)[2]}"
  domain = join(",", slice(split(".", local.env.external_domain), 0, 0))
  sub_domain  = split(".", local.env.external_domain)[0]
}

data "cloudfoundry_domain" "internal" {
  domain      = join(",", slice(split(".", local.env.external_domain), 0, 0))
  sub_domain  = split(".", local.env.internal_domain)[0]
}

data "cloudfoundry_org" "this" {
  name = local.env.organization
}

data "cloudfoundry_space" "this" {
  name  = try(format(local.space_pattern, local.env.space), terraform.workspace)
  org   = data.cloudfoundry_org.this.id
}


data "cloudfoundry_service" "this" {
  for_each = {
  for key, value in try(local.env.services, {}) : key => value
  if value.service_type != "user-provided" && try(data.cloudfoundry_space.this.id, null) != null
  }
  
  name          = each.value.service_type
  space         = try(data.cloudfoundry_space.this.id, null)
}