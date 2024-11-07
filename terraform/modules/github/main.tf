data "github_repository" "this" {
  full_name = var.repository
}

resource "github_actions_secret" "this" {
  for_each = { for key, value in try(var.env.secrets, []) : key => value }
  repository       = data.github_repository.this.name
  secret_name      = each.key
  plaintext_value = !try(each.value.encrypted, false) ? try(var.secrets[each.value.key], null) : null
  encrypted_value  = try(each.value.encrypted, false) ? try(var.secrets[each.value.key], null) : null
}

resource "github_actions_variable" "this" {
  for_each = { for key, value in try(var.variables, []) : key => value }
  repository    = data.github_repository.this.name
  variable_name = each.key
  value         = each.value
}
