resource "cloudfoundry_route" "external" {
  for_each = { for key, value in try(var.env.apps, {}) : key => value
    if value.public_route && try(value.port, -1) != -1
  }

  domain = var.cloudfoundry.domain_external.id
  #space = var.cloudfoundry.space.id
  space = try(var.cloudfoundry.spaces[each.value.space].id, var.cloudfoundry.space.id)
  hostname = format(var.env.name_pattern, each.key)
  port = try(cloudfoundry_app.this[each.key].port, null)

  target {
    app = cloudfoundry_app.this[each.key].id
    port = 0
  }
}

resource "cloudfoundry_route" "internal" {
  for_each = {
    for key, value in try(var.env.apps, {}) : key => value
    if !value.public_route && try(value.port, -1) != -1
  }

  domain = var.cloudfoundry.domain_internal.id
  #space = var.cloudfoundry.space.id
  space = try(var.cloudfoundry.spaces[each.value.space].id, var.cloudfoundry.space.id)
  hostname = format(var.env.name_pattern, each.key)
  port = try(cloudfoundry_app.this[each.key].port, null)

  target {
    app = cloudfoundry_app.this[each.key].id
    port = 0
  }
}
