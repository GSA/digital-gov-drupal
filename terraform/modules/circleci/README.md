<!-- BEGIN_TF_DOCS -->
# CircleCI Module

## Introduction

This terraform module creates and sets CircleCI project/context variables and scheduled (cron-like) pipelines.

** NOTE: Unless specific permissions are granted to the GSA project, the project won't have access to contexts.

## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_circleci"></a> [circleci](#requirement\_circleci) | 0.8.2 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_circleci"></a> [circleci](#provider\_circleci) | 0.8.2 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [circleci_context.this](https://registry.terraform.io/providers/healx/circleci/0.8.2/docs/resources/context) | resource |
| [circleci_context_environment_variable.this](https://registry.terraform.io/providers/healx/circleci/0.8.2/docs/resources/context_environment_variable) | resource |
| [circleci_environment_variable.this](https://registry.terraform.io/providers/healx/circleci/0.8.2/docs/resources/environment_variable) | resource |
| [circleci_schedule.schedule](https://registry.terraform.io/providers/healx/circleci/0.8.2/docs/resources/schedule) | resource |
| [circleci_context.this](https://registry.terraform.io/providers/healx/circleci/0.8.2/docs/data-sources/context) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_context_name"></a> [context\_name](#input\_context\_name) | The CircleCI context to add variables to. | `string` | `null` | no |
| <a name="input_env"></a> [env](#input\_env) | Project environmental variables. | `any` | n/a | yes |
| <a name="input_schedules"></a> [schedules](#input\_schedules) | Set a scheduled pipeline. | `any` | `{}` | no |
| <a name="input_secrets"></a> [secrets](#input\_secrets) | Sensitive credentials to be used with the application. | `map(string)` | `{}` | no |

## Outputs

No outputs.

## Examples

```terraform
module "circleci" {
  source = "./modules/circleci"
  env = local.env
  services = local.services
  secrets = local.secrets
  schedules = local.env.circleci.schedules
}
```
<!-- END_TF_DOCS -->