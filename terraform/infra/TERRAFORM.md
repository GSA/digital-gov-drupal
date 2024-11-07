<!-- BEGIN_TF_DOCS -->
# Cloud.gov Drupal Infrastructure

## Requirements

No requirements.

## Providers

| Name | Version |
|------|---------|
| <a name="provider_cloudfoundry"></a> [cloudfoundry](#provider\_cloudfoundry) | 0.51.2 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_applications"></a> [applications](#module\_applications) | ./modules/application | n/a |
| <a name="module_certificates"></a> [certificates](#module\_certificates) | ./modules/certificate | n/a |
| <a name="module_circleci"></a> [circleci](#module\_circleci) | ./modules/circleci | n/a |
| <a name="module_random"></a> [random](#module\_random) | ./modules/random | n/a |
| <a name="module_secrets"></a> [secrets](#module\_secrets) | ./modules/service | n/a |
| <a name="module_services"></a> [services](#module\_services) | ./modules/service | n/a |

## Resources

| Name | Type |
|------|------|
| [cloudfoundry_app.egress_proxy](https://registry.terraform.io/providers/hashicorp/cloudfoundry/latest/docs/data-sources/app) | data source |
| [cloudfoundry_app.external_applications](https://registry.terraform.io/providers/hashicorp/cloudfoundry/latest/docs/data-sources/app) | data source |
| [cloudfoundry_domain.external](https://registry.terraform.io/providers/hashicorp/cloudfoundry/latest/docs/data-sources/domain) | data source |
| [cloudfoundry_domain.internal](https://registry.terraform.io/providers/hashicorp/cloudfoundry/latest/docs/data-sources/domain) | data source |
| [cloudfoundry_org.this](https://registry.terraform.io/providers/hashicorp/cloudfoundry/latest/docs/data-sources/org) | data source |
| [cloudfoundry_route.egress_proxy](https://registry.terraform.io/providers/hashicorp/cloudfoundry/latest/docs/data-sources/route) | data source |
| [cloudfoundry_service.this](https://registry.terraform.io/providers/hashicorp/cloudfoundry/latest/docs/data-sources/service) | data source |
| [cloudfoundry_space.egress_proxy](https://registry.terraform.io/providers/hashicorp/cloudfoundry/latest/docs/data-sources/space) | data source |
| [cloudfoundry_space.this](https://registry.terraform.io/providers/hashicorp/cloudfoundry/latest/docs/data-sources/space) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_circleci_token"></a> [circleci\_token](#input\_circleci\_token) | CircleCI token. | `string` | n/a | yes |
| <a name="input_cloudgov_password"></a> [cloudgov\_password](#input\_cloudgov\_password) | The password for the cloud.gov account. | `string` | n/a | yes |
| <a name="input_cloudgov_username"></a> [cloudgov\_username](#input\_cloudgov\_username) | The username for the cloudfoundry account. | `string` | n/a | yes |
| <a name="input_mtls_port"></a> [mtls\_port](#input\_mtls\_port) | The default port to direct traffic to. Envoy proxy listens on 61443 and redirects to 8080, which the application should listen on. | `number` | `61443` | no |
| <a name="input_newrelic_key"></a> [newrelic\_key](#input\_newrelic\_key) | The API key for New Relic. | `string` | n/a | yes |
| <a name="input_no_proxy"></a> [no\_proxy](#input\_no\_proxy) | URIs that shouldn't be using the proxy to communicate. | `string` | `"apps.internal"` | no |
| <a name="input_proxy_password"></a> [proxy\_password](#input\_proxy\_password) | The proxy password. | `string` | n/a | yes |
| <a name="input_proxy_username"></a> [proxy\_username](#input\_proxy\_username) | The proxy username. | `string` | n/a | yes |

## Outputs

No outputs.

### locals.tf Overview

This is a high level overview of the `locals.tf` file. The locals.tf file itself is heavily commented and will go into detail about individual settings if further information is required.

The locals.tf is the main file that needs to be edited to configure your infrastructure.

####  Global variables

##### project

This variable holds the prefix of your resource names. For example, this project uses `benefit-finder` as a prefix for service names.

##### project\_full

This variable is a longer, alternative name used in the project. For example, CircleCI calls this project `benefit-finder-gov`.

##### bootstrap\_workspace

The name of the `bootstrap` workspace in Terraform. By default, it's `bootstrap`.

##### global

An object that sets commonly used applications and services (i.e. the WAF and the database), making configuration easier.

##### egress

Settings for the egress proxy that is deployed to the DMZ space.

##### external\_applications

Settings for applications that aren't managed by Terraform. This is used to save pipeline variables to dynamically configure the other application.

##### envs

Settings for the majority of the deployment, that is then merged into a single `object`. The sub-object, `all` are configurations for every environment. The other sub-objects should be the name of your Terraform workspaces.

### local.env.apps
This is a `map` of `objects`.

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| buildpack | The admin buildpack name or Git URL | `string` | `null` | no |
| buildpacks | A list of buildpack names and/or Git URLs | `list(string)` | `null` | no |
| command | A custom start command for the application. A custom start command for the application. | `string` | `null` | no |
| disk\_quota | The size of the buildpack's ephemeral disk in megabytes. | `number` | `1024` | no |
| docker\_credentials | A custom start command for the application. | `map` | `null` | no |
| docker\_image | The URL to the docker image with tag. | `string` | `null` | no |
| enable\_ssh | Whether to enable or disable SSH access to the container. | `bool` | `true` | no |
| environment | Key/value pairs of custom environment variables to set in your app. | `map` | `null` | no |
| health\_check\_http\_endpoint | The endpoint for the http health check type. | `string` | `"/"` | no |
| health\_check\_invocation\_timeout | The timeout in seconds for individual health check requests for "http" and "port" health checks. | `number` | `5` | no |
| health\_check\_timeout | The timeout in seconds for the health check. | `number` | `180` | no |
| health\_check\_type | The timeout in seconds for individual health check requests for "http" and "port" health checks. | `string` | `"port"` | no |
| instances | The number of app instances that you want to start. | `number` | `1` | no |
| labels | Adds labels to the application. | `map` | `null` | no |
| memory | The memory limit for each application instance in megabytes. | `number` | `64` | no |
| name | The name of the application. | `string` | n/a | yes |
| path | An URI or path to target a zip file. If the path is a directory, the module will create a zip file. | `string` | n/a | yes |
| space | The GUID of the associated Cloud Foundry space. | `string` | n/a | yes |
| stack | The name of the stack the application will be deployed to. `cf stacks` will list valid options. | `string` | `"cflinuxfs4"` | no |
| stopped | Defines the desired application state. Set to true to have the application remain in a stopped state. | `bool` | `false` | no |
| strategy | Strategy ("none", "blue-green", or "rolling") to use for creating/updating application. | `string` | `"none"` | no |
| timeout | Max wait time for app instance startup, in seconds. | `number` | `60` | no |

### local.env.services
This is a `map` of `objects`.

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| name                           | The name of the service instance. | `string` | n/a | yes |
| json\_params                    | A json string of arbitrary parameters. | `string` | `null` | no |
| replace\_on\_params\_change       | Cloud Foundry will replace the resource on any params change. | `bool` | `false` | no |
| replace\_on\_service\_plan\_change | Cloud Foundry will replace the resource on any service plan changes | `bool` | `false` | no |
| space                          | The ID of the space. | `string` | n/a | yes |
| service\_plan                   | The ID of the service plan. | `string` | n/a | yes |
| tags                           | List of instance tags. | `list(string)` | `[]` | no |
<!-- END_TF_DOCS -->