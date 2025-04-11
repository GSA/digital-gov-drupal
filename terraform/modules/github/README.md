<!-- BEGIN_TF_DOCS -->
# Github Secrets and Variables

## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | > 1.7 |
| <a name="requirement_github"></a> [github](#requirement\_github) | ~> 6.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_github"></a> [github](#provider\_github) | ~> 6.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [github_actions_secret.this](https://registry.terraform.io/providers/integrations/github/latest/docs/resources/actions_secret) | resource |
| [github_actions_variable.this](https://registry.terraform.io/providers/integrations/github/latest/docs/resources/actions_variable) | resource |
| [github_repository.this](https://registry.terraform.io/providers/integrations/github/latest/docs/data-sources/repository) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_env"></a> [env](#input\_env) | The settings object for this environment. | <pre>object({<br>    api_url               = optional(string, "https://api.fr.cloud.gov")<br>    apps = optional(<br>      map(<br>        object({<br>          allow_egress         = optional(bool, true)<br>          buildpacks           = list(string)<br>          command              = optional(string, "entrypoint.sh")<br>          disk_quota           = optional(number, 1024)<br>          enable_ssh           = optional(bool, false)<br>          environment          = optional(map(string), {})<br>          health_check_timeout = optional(number, 180)<br>          health_check_type    = optional(string, "port")<br>          instances            = optional(number, 1)<br>          labels = optional(map(string), {})<br>          memory = optional(number, 96)<br>          network_policies = optional(map(number),{})<br>          port         = optional(number, 80)<br>          public_route = optional(bool, false)<br>          source       = optional(string, null)<br>          templates    = list(map(string))<br>        })<br>      ), {}<br>    )<br>    bootstrap_workspace = optional(string, "bootstrap")<br>    defaults = object(<br>      {<br>        disk_quota           = optional(number, 2048)<br>        enable_ssh           = optional(bool, true)<br>        health_check_timeout = optional(number, 60)<br>        health_check_type    = optional(string, "port")<br>        instances            = optional(number, 1)<br>        memory               = optional(number, 64)<br>        port                 = optional(number, 8080)<br>        stack                = optional(string, "cflinuxfs4")<br>        stopped              = optional(bool, false)<br>        strategy             = optional(string, "none")<br>        timeout              = optional(number, 300)<br>      }<br>    )<br>    external_applications = optional(<br>      map(<br>        object(<br>          {<br>            name       = string<br>            environement = string<br>            port       = optional(number, 61443)<br>          }<br>        )<br>      ),{}<br>    )<br>    external_domain = optional(string, "app.cloud.gov")<br>    internal_domain = optional(string, "apps.internal")<br>    name_pattern    = string<br>    organization    = optional(string, "gsa-tts-usagov")<br>    passwords = optional(<br>      map(<br>        object(<br>          {<br>            experation_days = optional(number, 0)<br>            length = number<br>            lower = optional(bool, false)<br>            min_lower = optional(number, 0)<br>            min_numeric = optional(number, 0)<br>            min_special = optional(number, 0)<br>            min_upper = optional(number, 0)<br>            numeric = optional(bool, true)<br>            override_special = optional(string, "!@#$%&*()-_=+[]{}<>:?")<br>            special = optional(bool, true)<br>            upper = optional(bool, true)<br>          }<br>        )<br>      ), {}<br>    )<br>    project = string<br>    secrets = optional(<br>      map(<br>        object(<br>          {<br>            encrypted = bool<br>            key = string<br>          }<br>        )<br>      ), {}<br>    )<br>    services = optional(<br>      map(<br>        object(<br>          {<br>            applications = optional(list(string), [])<br>            environement = optional(string, "dev")<br>            service_key  = optional(bool, true)<br>            service_plan = optional(string, "basic")<br>            service_type = optional(string, "s3")<br>            tags         = optional(list(string), [])<br>          }<br>        )<br>      ), {}<br>    )<br>    space = string<br>  })</pre> | n/a | yes |
| <a name="input_github_organization"></a> [github\_organization](#input\_github\_organization) | The organization to use with GitHub. | `string` | `"GSA"` | no |
| <a name="input_github_token"></a> [github\_token](#input\_github\_token) | The token used authenticate with GitHub. | `string` | n/a | yes |
| <a name="input_repository"></a> [repository](#input\_repository) | The GitHub respository. | `string` | n/a | yes |
| <a name="input_secrets"></a> [secrets](#input\_secrets) | Secrets to create in the respository. | `map(string)` | `{}` | no |
| <a name="input_variables"></a> [variables](#input\_variables) | Variables to create in the respository. | `map(string)` | `{}` | no |

## Outputs

No outputs.

## Runbook

For a deeper breakdown of this module, you can read the full runbook for this module. A runbook is a collection of documented procedures, guidelines, and best practices used by teams, typically in IT operations and system administration, to handle routine processes and incidents efficiently. Runbooks provide step-by-step instructions and checklists to troubleshoot problems, maintain systems, and manage various tasks.

[Runbook](RUNBOOK.md)
<!-- END_TF_DOCS -->