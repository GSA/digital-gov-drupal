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

## Runbook

For a deeper breakdown of this module, you can read the full runbook for this module. A runbook is a collection of documented procedures, guidelines, and best practices used by teams, typically in IT operations and system administration, to handle routine processes and incidents efficiently. Runbooks provide step-by-step instructions and checklists to troubleshoot problems, maintain systems, and manage various tasks.

[Runbook](RUNBOOK.md)