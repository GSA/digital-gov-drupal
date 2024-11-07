locals {

  ## Used as an "alias" so when 'hours_of_day' is set to '["*"]', it will replace it with every hour in a day.
  every_hour = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23]

  ## Used as an "alias" so when 'days_of_week' is set to '["*"]', it will replace it with every day in a week.
  every_day  = ["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"]

  ## Is the current workspace the 'bootstrap' environment?
  is_bootstrap = terraform.workspace == var.env.bootstrap_workspace ? true : false

  ## Is the current workspace the 'dmz' environment?
  is_dmz = terraform.workspace == "dmz" ? true : false

  ## Ignore 'bootstrap' and 'dmz' workspaces.
  is_special_space = local.is_bootstrap || local.is_dmz ? true : false

  ## A map of secrets filtered through the list of CircleCI variables.
  /* circleci_variables = merge(
    flatten([
      for value in try(var.env.circleci_variables, []) : [
        {
          "${value}" = "${var.secrets["${value}"]}"
        }
      ]
    ])
  ...) */
}

## Get the context if 'var.context_name' is set and we aren't in the bootstrap environment.
## NOTE: The context gets created in the 'bootstrap' environment.
data "circleci_context" "this" {
  count = try(var.context_name, null) != null && terraform.workspace != var.env.bootstrap_workspace ? 1 : 0
  name = var.context_name
}

# Create the context if 'var.context' is set and we are in the bootstrap environment.
resource "circleci_context" "this" {
  count = try(var.context_name, null) != null && terraform.workspace == var.env.bootstrap_workspace ? 1 : 0
  organization = try(var.env.circleci.organization, null)
  name = var.context_name
}

## Creates a new environmental variable that is assigned to a context, if 'var.context_name' is set.
resource "circleci_context_environment_variable" "this" {
  for_each = {
    for key, value in try(var.env.circleci_variables, []) : value => value
    if var.context_name != null
  }

  context_id = try(data.circleci_context.this[0].id, circleci_context.this[0].id)
  variable = local.is_special_space ? format("%s", each.key) : format("%s_%s", terraform.workspace, each.key)
  value = var.secrets[each.key]
}

## Creates a new environmental that is assigned to the project, if 'var.context_name' is NOT set.
resource "circleci_environment_variable" "this" {
  for_each = {
    for key, value in try(var.env.circleci_variables, []) : value => value
    if var.context_name == null
  }

  project = var.env.circleci.project
  name = local.is_special_space ? format("%s", each.key) : format("%s_%s", terraform.workspace, each.key)
  value = var.secrets[each.key]
}

## Creates a scheduled pipeline, which runs at reoccuring times.
resource "circleci_schedule" "schedule" {
  for_each = {
    for key, value in var.schedules : key => value
    if !contains(value.ignore_workspace, terraform.workspace)
  }

  name                  = format(var.env.name_pattern, each.key)
  organization          = try(var.env.circleci.organization, null)
  project               = var.env.circleci.project
  description           = try(each.value.description, null)
  per_hour              = try(each.value.per_hour, 1)
  hours_of_day          = try(
    each.value.hours_of_day[0] == "*" ? local.every_hour : try(each.value.hours_of_day,
    [9,23])
  )
  days_of_week          = try(
    each.value.days_of_week[0] == "*" ? local.every_day : try(each.value.days_of_week,
    ["MON", "TUES"])
  )
  use_scheduling_system = try(each.value.scheduling_system, true)
  parameters_json = jsonencode(
    try(each.value.parameters, {})
  )
}
