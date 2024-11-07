locals {
  merged_applications = merge(cloudfoundry_app.this, var.cloudfoundry.external_applications)
}

resource "cloudfoundry_network_policy" "ingress_proxy" {
  for_each = {
    for key, value in try(var.env.apps, []) : value.name => value
    if try(value.network_policy, null) != null &&
       try(var.cloudfoundry.external_applications[value.network_policy.name].id, null) != null
  }
  policy {
      source_app = cloudfoundry_app.this[each.key].id
      destination_app = var.cloudfoundry.external_applications[each.value.network_policy.name].id
      port = try(var.env.apps[each.key].network_policy_app.port, 8080)
      protocol = try(var.env.apps[each.key].network_policy_app.protocol, "tcp")
  }
}

resource "cloudfoundry_network_policy" "egress_proxy" {
  for_each = {
    for key, value in try(var.env.apps, []) : value.name => value
    if try(var.cloudfoundry.egress_app.id, null) != null &&
    terraform.workspace != try(var.env.egress.workspace, null)
  }

  policy {
      source_app = cloudfoundry_app.this[each.key].id
      destination_app = try(var.cloudfoundry.egress_app.id, null)
      port = try(var.env.egress.mtls_port, 61443)
      protocol = try(var.env.egress.protocol, "tcp")
  }
}
