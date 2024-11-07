<!-- BEGIN_TF_DOCS -->
# CloudFoundry Application Module

## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | > 1.7 |
| <a name="requirement_cloudfoundry"></a> [cloudfoundry](#requirement\_cloudfoundry) | ~> 0.5 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_archive"></a> [archive](#provider\_archive) | n/a |
| <a name="provider_cloudfoundry"></a> [cloudfoundry](#provider\_cloudfoundry) | ~> 0.5 |
| <a name="provider_local"></a> [local](#provider\_local) | n/a |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [cloudfoundry_app.this](https://registry.terraform.io/providers/cloudfoundry-community/cloudfoundry/latest/docs/resources/app) | resource |
| [cloudfoundry_network_policy.egress_proxy](https://registry.terraform.io/providers/cloudfoundry-community/cloudfoundry/latest/docs/resources/network_policy) | resource |
| [cloudfoundry_network_policy.ingress_proxy](https://registry.terraform.io/providers/cloudfoundry-community/cloudfoundry/latest/docs/resources/network_policy) | resource |
| [cloudfoundry_route.external](https://registry.terraform.io/providers/cloudfoundry-community/cloudfoundry/latest/docs/resources/route) | resource |
| [cloudfoundry_route.internal](https://registry.terraform.io/providers/cloudfoundry-community/cloudfoundry/latest/docs/resources/route) | resource |
| [local_sensitive_file.this](https://registry.terraform.io/providers/hashicorp/local/latest/docs/resources/sensitive_file) | resource |
| [archive_file.this](https://registry.terraform.io/providers/hashicorp/archive/latest/docs/data-sources/file) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_cloudfoundry"></a> [cloudfoundry](#input\_cloudfoundry) | Cloudfoundry settings. | <pre>object(<br>    {<br>      domain_external = object(<br>        {<br>          domain = string<br>          id = string<br>          internal = bool<br>          name = string<br>          org = string<br>          sub_domain = string<br>        }<br>      )<br>      domain_internal = object(<br>        {<br>          domain = string<br>          id = string<br>          internal = bool<br>          name = string<br>          org = string<br>          sub_domain = string<br>        }<br>      )<br>      external_applications = optional(<br>        map(<br>          object(<br>            {<br>              name       = string<br>              environement = string<br>              port       = optional(number, 61443)<br>            }<br>          )<br>        ),{}<br>      )<br>      organization = object(<br>        {<br>          annotations = map(string)<br>          id = string<br>          labels = map(string)<br>          name = string<br>        }<br>      )<br>      services = map(<br>        object(<br>          {<br>            id = string<br>            name = string<br>            service_broker_guid = string<br>            service_broker_name = string<br>            service_plans = map(string)<br>            space = string<br>          }<br>        )<br>      )<br>      space = object(<br>        {<br>          annotations = map(string)<br>          id = string<br>          labels = map(string)<br>          name = string<br>          org = string<br>          org_name = string<br>          quota = string<br>        }<br>      )<br>    }<br>  )</pre> | n/a | yes |
| <a name="input_env"></a> [env](#input\_env) | The settings object for this environment. | <pre>object({<br>    api_url               = optional(string, "https://api.fr.cloud.gov")<br>    apps = optional(<br>      map(<br>        object({<br>          allow_egress         = optional(bool, true)<br>          buildpacks           = list(string)<br>          command              = optional(string, "entrypoint.sh")<br>          disk_quota           = optional(number, 1024)<br>          enable_ssh           = optional(bool, false)<br>          environment          = optional(map(string), {})<br>          health_check_timeout = optional(number, 180)<br>          health_check_type    = optional(string, "port")<br>          instances            = optional(number, 1)<br>          labels = optional(map(string), {})<br>          memory = optional(number, 96)<br>          network_policies = optional(map(number),{})<br>          port         = optional(number, 80)<br>          public_route = optional(bool, false)<br>          space        = optional(string ,null)<br>          source       = optional(string, null)<br>          templates    = list(map(string))<br>        })<br>      ), {}<br>    )<br>    bootstrap_workspace = optional(string, "bootstrap")<br>    defaults = object(<br>      {<br>        disk_quota           = optional(number, 2048)<br>        enable_ssh           = optional(bool, true)<br>        health_check_timeout = optional(number, 60)<br>        health_check_type    = optional(string, "port")<br>        instances            = optional(number, 1)<br>        memory               = optional(number, 64)<br>        port                 = optional(number, 8080)<br>        stack                = optional(string, "cflinuxfs4")<br>        stopped              = optional(bool, false)<br>        strategy             = optional(string, "none")<br>        timeout              = optional(number, 300)<br>      }<br>    )<br>    external_applications = optional(<br>      map(<br>        object({<br>          enable_ssh = optional(bool, false)<br>          instances  = optional(number, 1)<br>          memory     = optional(number, 96)<br>          port       = optional(number, 61443)<br>        })<br>      ), {}<br>    )<br>    external_domain = optional(string, "app.cloud.gov")<br>    internal_domain = optional(string, "apps.internal")<br>    name_pattern    = string<br>    organization    = optional(string, "gsa-tts-usagov")<br>    passwords = optional(<br>      list(<br>        object(<br>          {<br>            length = optional(number, 32)<br>          }<br>        )<br>      ), []<br>    )<br>    project = string<br>    secrets = optional(<br>      map(<br>        object(<br>          {<br>            encrypted = bool<br>            key = string<br>          }<br>        )<br>      ), {}<br>    )<br>    services = optional(<br>      map(<br>        object(<br>          {<br>            applications = optional(list(string), [])<br>            environement = optional(string, "dev")<br>            service_key  = optional(bool, true)<br>            service_plan = optional(string, "basic")<br>            service_type = optional(string, "s3")<br>            tags         = optional(list(string), [])<br>          }<br>        )<br>      ), {}<br>    )<br>    space = string<br>  })</pre> | n/a | yes |
| <a name="input_secrets"></a> [secrets](#input\_secrets) | Sensitive credentials to be used to set application environmental variables. | `map(string)` | `{}` | no |
| <a name="input_services"></a> [services](#input\_services) | Services generated from the service module. | <pre>object(<br>    {<br>      instance = map(<br>        object(<br>          {<br>            annotations = optional(string, null)<br>            id = optional(string, null)<br>            json_params = optional(string, null)<br>            labels = optional(map(string), {})<br>            name = optional(string, null)<br>            recursive_delete = optional(bool, null)<br>            replace_on_params_change = optional(bool, false)<br>            replace_on_service_plan_change = optional(bool, false)<br>            service_plan = optional(string, null)<br>            space = optional(string, null)<br>            tags = optional(list(string), null)<br>          }<br>        )<br>      )<br>      user_provided = map(<br>        object(<br>          {<br>            annotations = optional(string, null)<br>            id = optional(string, null)<br>            json_params = optional(string, null)<br>            labels = optional(map(string), {})<br>            name = optional(string, null)<br>            recursive_delete = optional(bool, null)<br>            replace_on_params_change = optional(bool, false)<br>            replace_on_service_plan_change = optional(bool, false)<br>            service_plan = optional(string, null)<br>            space = optional(string, null)<br>            tags = optional(list(string), null)<br>          }<br>        )<br>      )<br>      service_key = map(<br>        object(<br>          {<br>            name = optional(string, null)<br>            service_instance = optional(string, null)<br>            params = optional(map(string), null)<br>            params_json = optional(string, null)<br>            credentials = optional(map(string), {})<br>          }<br>        )<br>      )<br>    }<br>  )</pre> | `null` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_apps"></a> [apps](#output\_apps) | A `map` of [cloudfoundry\_app](https://registry.terraform.io/providers/cloudfoundry-community/cloudfoundry/latest/docs/resources/app) resource outputs. The key is the app name. |
| <a name="output_external_endpoints"></a> [external\_endpoints](#output\_external\_endpoints) | A map of external URL's (app.cloud.gov) to used to reach an application. The key is the app name. |
| <a name="output_internal_endpoints"></a> [internal\_endpoints](#output\_internal\_endpoints) | A map of internal URL's (apps.internal) to used to reach an application. The key is the app name. |

## Example

```terraform
module "applications" {
  source = "./modules/application"

  cloudfoundry = local.cloudfoundry
  env = local.env
  secrets = local.secrets
  services = local.services
}
```

## Variables

### cloudfoundry

A variable that contains a `map(string)` of data lookups for pre-existing resources from Cloud.gov. This includes thing such as the organization and space ids. These are defined in `data.tf` in the root directory.

### env

A mixed type `object` variable that contains application settings. It is passed as an `any` type to allow optional variables to be ommitted from the object. It is defined in `locals.tf`, in the root directory. The object `local.env[terraform.workspace].apps` stores the values for the specific application that is to be deployed.

Valid options are the attributes for the [cloudfoundry\_app](https://registry.terraform.io/providers/cloudfoundry-community/cloudfoundry/latest/docs/resources/app) resource.

### secrets

A variable that has secrets and other credentials that the application uses. The `local.secrets` variable is generated in `locals_dynamic.tf`, as it merges a variety of credentials from the random and services modules.

### services

A variable that contains a `map(map(string))` of the services deployed in the environment. `local.services` is generated in `locals_dynamic.tf`, due to needing to be generated after the creation of the services, after the instance id are known. The services are then bound to the application.

See the [service module](../service/readme.MD) for more information.

## Usage

Here is an example of how to define an application in `locals.tf`.

```terraform
locals {
  env = {
    workspace1 = {
      apps = {
        application1 = {
          buildpacks = [
            "staticfile_buildpack"
          ]
          command = "./start"
          disk_quota = 256
          enable_ssh = true
          environment = {
            environment = terraform.workspace
            LD_LIBRARY_PATH = "/home/vcap/deps/0/lib/"      
          }
          health_check_timeout = 180
          health_check_type = "port"
          instances = 1
          labels = {
            environment = terraform.workspace
          }
          memory        = 64
          port          = 8080
          public_route  = false

          source        = "/path/to/application/directory"

          templates     = [
            {
              source      = "${path.cwd}/path/to/templates/template.tmpl"
              destination = "${path.cwd}}/path/to/templates/file"
            }
          ]
        }
      }
    }
  }
}
```

## Additional Notes

- Buildpacks
    - Valid built-in Cloud.gov buildpacks can be found by running `cf buildpacks` from the CLI.
    - External buildpacks, such as the `apt-buildpack` by referencing the URL to the buildpack repository: [https://github.com/cloudfoundry/apt-buildpack](https://github.com/cloudfoundry/apt-buildpack).
<!-- END_TF_DOCS -->