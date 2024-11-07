<!-- BEGIN_TF_DOCS -->
# Random Module

## Introduction

This module generates random credentials and hashes that can be used in various applications.

## Requirements

No requirements.

## Providers

| Name | Version |
|------|---------|
| <a name="provider_random"></a> [random](#provider\_random) | n/a |
| <a name="provider_time"></a> [time](#provider\_time) | n/a |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [random_password.multiple](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/password) | resource |
| [random_password.single](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/password) | resource |
| [time_rotating.multiple](https://registry.terraform.io/providers/hashicorp/time/latest/docs/resources/rotating) | resource |
| [time_rotating.single](https://registry.terraform.io/providers/hashicorp/time/latest/docs/resources/rotating) | resource |
| [time_static.multiple](https://registry.terraform.io/providers/hashicorp/time/latest/docs/resources/static) | resource |
| [time_static.single](https://registry.terraform.io/providers/hashicorp/time/latest/docs/resources/static) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_names"></a> [names](#input\_names) | List of unique names for the multiple resources. | `list(string)` | `[]` | no |
| <a name="input_passwords"></a> [passwords](#input\_passwords) | A map of objects with password settings. | <pre>map(<br>    object(<br>      {<br>        experation_days = optional(number, 0)<br>        length = number<br>        lower = optional(bool, false)<br>        min_lower = optional(number, 0)<br>        min_numeric = optional(number, 0)<br>        min_special = optional(number, 0)<br>        min_upper = optional(number, 0)<br>        numeric = optional(bool, true)<br>        override_special = optional(string, "!@#$%&*()-_=+[]{}<>:?")<br>        special = optional(bool, true)<br>        upper = optional(bool, true)<br>      }<br>    )<br>  )</pre> | n/a | yes |
| <a name="input_per_workspace"></a> [per\_workspace](#input\_per\_workspace) | Generate a password for each workspace. | `bool` | `false` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_results"></a> [results](#output\_results) | A map(string) with the following attributes: result, md5, sha1sha256, and sha512. |

## Example

```terraform
module "random" {
  source = "./modules/random"

  names = ["dev", "stage", "prod"]
  passwords = local.env.passwords
}
```

## Usage

### locals.tf

Passwords to be generated are set in `local.env.passwords`.

```terraform
locals {
  env = {
    ...
    workspace_name = {
      ...
      passwords = {
        password1 = {
          length = 16
          special = false
        }
      }
    }
  }
}
```

If the attribute `per_workspace` is set for `true`, then `multiple` resources will be created. It will prefix each resource name with each workspace name. It is useful to set this in the `bootstrap` "environment", allowing the passwords to be added as pipeline variables for each environment.

```terraform
locals {
  env = {
    ...
    bootstrap = {
      ...
      passwords = {
        password2 = {
          length = 32
          per_workspace = true
        }
      }
    }
  }
}
```

If the `per_workspace` value isn't set or is `false`, only `single` resource will be created.
<!-- END_TF_DOCS -->