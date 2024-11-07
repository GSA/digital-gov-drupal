### locals.tf Overview

This is a high level overview of the `locals.tf` file. The locals.tf file itself is heavily commented and will go into detail about individual settings if further information is required.

The locals.tf is the main file that needs to be edited to configure your infrastructure.

####  Global variables

##### project

This variable holds the prefix of your resource names. For example, this project uses `benefit-finder` as a prefix for service names.

##### project_full

This variable is a longer, alternative name used in the project. For example, CircleCI calls this project `benefit-finder-gov`.

##### bootstrap_workspace

The name of the `bootstrap` workspace in Terraform. By default, it's `bootstrap`.

##### global

An object that sets commonly used applications and services (i.e. the WAF and the database), making configuration easier.

##### egress

Settings for the egress proxy that is deployed to the DMZ space.

##### external_applications

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
| disk_quota | The size of the buildpack's ephemeral disk in megabytes. | `number` | `1024` | no |
| docker_credentials | A custom start command for the application. | `map` | `null` | no |
| docker_image | The URL to the docker image with tag. | `string` | `null` | no |
| enable_ssh | Whether to enable or disable SSH access to the container. | `bool` | `true` | no |
| environment | Key/value pairs of custom environment variables to set in your app. | `map` | `null` | no |
| health_check_http_endpoint | The endpoint for the http health check type. | `string` | `"/"` | no |
| health_check_invocation_timeout | The timeout in seconds for individual health check requests for "http" and "port" health checks. | `number` | `5` | no |
| health_check_timeout | The timeout in seconds for the health check. | `number` | `180` | no |
| health_check_type | The timeout in seconds for individual health check requests for "http" and "port" health checks. | `string` | `"port"` | no |
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
| json_params                    | A json string of arbitrary parameters. | `string` | `null` | no |
| replace_on_params_change       | Cloud Foundry will replace the resource on any params change. | `bool` | `false` | no |
| replace_on_service_plan_change | Cloud Foundry will replace the resource on any service plan changes | `bool` | `false` | no |
| space                          | The ID of the space. | `string` | n/a | yes |
| service_plan                   | The ID of the service plan. | `string` | n/a | yes |
| tags                           | List of instance tags. | `list(string)` | `[]` | no |