<!-- BEGIN_TF_DOCS -->
# CloudFoundry Service Module

## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | > 1.7 |
| <a name="requirement_cloudfoundry"></a> [cloudfoundry](#requirement\_cloudfoundry) | ~> 0.5 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_cloudfoundry"></a> [cloudfoundry](#provider\_cloudfoundry) | ~> 0.5 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [cloudfoundry_service_instance.this](https://registry.terraform.io/providers/cloudfoundry-community/cloudfoundry/latest/docs/resources/service_instance) | resource |
| [cloudfoundry_service_key.this](https://registry.terraform.io/providers/cloudfoundry-community/cloudfoundry/latest/docs/resources/service_key) | resource |
| [cloudfoundry_user_provided_service.this](https://registry.terraform.io/providers/cloudfoundry-community/cloudfoundry/latest/docs/resources/user_provided_service) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_cloudfoundry"></a> [cloudfoundry](#input\_cloudfoundry) | Cloudfoundry settings. | <pre>object(<br>    {<br>      domain_external = object(<br>        {<br>          domain = string<br>          id = string<br>          internal = bool<br>          name = string<br>          org = string<br>          sub_domain = string<br>        }<br>      )<br>      domain_internal = object(<br>        {<br>          domain = string<br>          id = string<br>          internal = bool<br>          name = string<br>          org = string<br>          sub_domain = string<br>        }<br>      )<br>      external_applications = map(string)<br>      organization = object(<br>        {<br>          annotations = map(string)<br>          id = string<br>          labels = map(string)<br>          name = string<br>        }<br>      )<br>      services = map(<br>        object(<br>          {<br>            id = string<br>            name = string<br>            service_broker_guid = string<br>            service_broker_name = string<br>            service_plans = map(string)<br>            space = string<br>          }<br>        )<br>      )<br>      space = object(<br>        {<br>          annotations = map(string)<br>          id = string<br>          labels = map(string)<br>          name = string<br>          org = string<br>          org_name = string<br>          quota = string<br>        }<br>      )<br>    }<br>  )</pre> | n/a | yes |
| <a name="input_env"></a> [env](#input\_env) | The settings object for this environment. | <pre>object({<br>    api_url               = optional(string, "https://api.fr.cloud.gov")<br>    apps = optional(<br>      map(<br>        object({<br>          allow_egress         = optional(bool, true)<br>          buildpacks           = list(string)<br>          command              = optional(string, "entrypoint.sh")<br>          disk_quota           = optional(number, 1024)<br>          enable_ssh           = optional(bool, false)<br>          environment          = optional(map(string), {})<br>          health_check_timeout = optional(number, 180)<br>          health_check_type    = optional(string, "port")<br>          instances            = optional(number, 1)<br>          labels = optional(map(string), {})<br>          memory = optional(number, 96)<br>          network_policies = optional(map(number),{})<br>          port         = optional(number, 80)<br>          public_route = optional(bool, false)<br>          source       = optional(string, null)<br>          templates    = list(map(string))<br>        })<br>      ), {}<br>    )<br>    bootstrap_workspace = optional(string, "bootstrap")<br>    defaults = object(<br>      {<br>        disk_quota           = optional(number, 2048)<br>        enable_ssh           = optional(bool, true)<br>        health_check_timeout = optional(number, 60)<br>        health_check_type    = optional(string, "port")<br>        instances            = optional(number, 1)<br>        memory               = optional(number, 64)<br>        port                 = optional(number, 8080)<br>        stack                = optional(string, "cflinuxfs4")<br>        stopped              = optional(bool, false)<br>        strategy             = optional(string, "none")<br>        timeout              = optional(number, 300)<br>      }<br>    )<br>    external_applications = optional(<br>      map(<br>        object(<br>          {<br>            environement = string<br>            port       = optional(number, 61443)<br>          }<br>        )<br>      ),{}<br>    )<br>    external_domain = optional(string, "app.cloud.gov")<br>    internal_domain = optional(string, "apps.internal")<br>    name_pattern    = string<br>    organization    = optional(string, "gsa-tts-usagov")<br>    passwords = optional(<br>      list(<br>        object(<br>          {<br>            length = optional(number, 32)<br>          }<br>        )<br>      ), []<br>    )<br>    project = string<br>    secrets = optional(<br>      map(<br>        object(<br>          {<br>            encrypted = bool<br>            key = string<br>          }<br>        )<br>      ), {}<br>    )<br>    services = optional(<br>      map(<br>        object(<br>          {<br>            applications = optional(list(string), [])<br>            environement = optional(string, "dev")<br>            service_key  = optional(bool, true)<br>            service_plan = optional(string, "basic")<br>            service_type = optional(string, "s3")<br>            tags         = optional(list(string), [])<br>          }<br>        )<br>      ), {}<br>    )<br>    space = string<br>  })</pre> | n/a | yes |
| <a name="input_secrets"></a> [secrets](#input\_secrets) | Sensitive strings to be added to the apps environmental variables. | `map` | `{}` | no |
| <a name="input_skip_service_instances"></a> [skip\_service\_instances](#input\_skip\_service\_instances) | Allows the skipping of service instances. Useful to inject service secrets into a user provided secret. | `bool` | `false` | no |
| <a name="input_skip_user_provided_services"></a> [skip\_user\_provided\_services](#input\_skip\_user\_provided\_services) | Allows the skipping of user provided services. Useful to inject service secrets into a user provided secret. | `bool` | `false` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_results"></a> [results](#output\_results) | n/a |

## Examples

### Basic
```terraform
module "services" {
  source = "./modules/service"

  cloudfoundry = local.cloudfoundry
  env = local.env
}
```

### Advanced

This advanced example will first generate service instances, such as RDS, along with other defined services, except for the `user defined` services. `User defined` services are useful for providing variables at runtime to applications. The issue is that until a service, such as RDS is deployed, their isn't a username and password created for that instance.

The first step is to initalize any services that are not `user defined`, but setting `skip_user_provided_services` to `true`.

```terraform
module "services" {
  source = "./modules/service"

  cloudfoundry = local.cloudfoundry
  env = local.env

  skip_user_provided_services = true
}
```

After the services are generated, another module block can be defined, which will pass a merged `map(string)` called `secrets`, that have the various information that is to be added to the `user defined` service. Setting the `skip_service_instances` to `true` will prevent the module from trying to redploy any non `user defined` service.

```terraform
module "secrets" {
  source = "./modules/service"

  cloudfoundry = local.cloudfoundry
  env = local.env

  secrets = local.secrets
  skip_service_instances = true
}
```
<!-- END_TF_DOCS -->