locals {
  passwords = merge(
    flatten([
      for name in var.names : [
        for key, value in var.passwords : {
          "${name}_${key}" = value
        } if try(value.per_workspace, false)
      ]
    ])
  ...)
}

resource "time_rotating" "single" {
  for_each          = {
    for key, value in var.passwords : key => value
    if try(value.expiration, 0) > 0
  }
  rotation_days = each.value.expiration_days
}

resource "time_static" "single" {
  for_each          = {
    for key, value in var.passwords : key => value
    if !var.per_workspace && try(value.expiration, 0) == 0
  }
}

resource "random_password" "single" {
  for_each         = {
     for key, value in var.passwords : key => value
     if !var.per_workspace
  }

  length            = try(each.value.length, 16)
  lower             = try(each.value.lower, true)
  min_lower         = try(each.value.min_lower, 0)
  min_numeric       = try(each.value.min_numeric, 0)
  min_special       = try(each.value.min_special, 0)
  numeric           = try(each.value.numeric, true)
  override_special  = try(each.value.override_special, "!#$%&*()-_=+[]{}<>:?")
  special           = try(each.value.special, false)
  upper             = try(each.value.upper, true)


  keepers = {
    id = try(time_rotating.single[each.key].id, null) != null ? time_rotating.single[each.key].id : time_static.single[each.key].id
  }
}

resource "time_rotating" "multiple" {
  for_each         = {
      for key, value in local.passwords : key => value
      if var.per_workspace && try(value.expiration, 0) > 0
  }
  rotation_days = each.value.expiration_days
}

resource "time_static" "multiple" {
  for_each         = {
      for key, value in local.passwords : key => value
      if var.per_workspace && try(value.expiration, 0) == 0
  }
}

resource "random_password" "multiple" {
  for_each         = {
      for key, value in local.passwords : key => value
      if var.per_workspace
  }

  length            = try(each.value.length, 16)
  lower             = try(each.value.lower, true)
  min_lower         = try(each.value.min_lower, 0)
  min_numeric       = try(each.value.min_numeric, 0)
  min_special       = try(each.value.min_special, 0)
  numeric           = try(each.value.numeric, true)
  override_special  = try(each.value.override_special, "!#$%&*()-_=+[]{}<>:?")
  special           = try(each.value.special, false)
  upper             = try(each.value.upper, true)

  keepers = {
    id = try(time_rotating.multiple[each.key].id, null) != null ? time_rotating.multiple[each.key].id : time_static.multiple[each.key].id
  }
}

