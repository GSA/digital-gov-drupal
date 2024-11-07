<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | > 1.7 |
| <a name="requirement_cloudfoundry"></a> [cloudfoundry](#requirement\_cloudfoundry) | ~> 0.5 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_cloudfoundry"></a> [cloudfoundry](#provider\_cloudfoundry) | 0.53.1 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_applications"></a> [applications](#module\_applications) | ../modules/application | n/a |
| <a name="module_github"></a> [github](#module\_github) | ../modules/github | n/a |
| <a name="module_random"></a> [random](#module\_random) | ../modules/random | n/a |
| <a name="module_services"></a> [services](#module\_services) | ../modules/service | n/a |

## Resources

| Name | Type |
|------|------|
| [cloudfoundry_app.external_applications](https://registry.terraform.io/providers/cloudfoundry-community/cloudfoundry/latest/docs/data-sources/app) | data source |
| [cloudfoundry_domain.external](https://registry.terraform.io/providers/cloudfoundry-community/cloudfoundry/latest/docs/data-sources/domain) | data source |
| [cloudfoundry_domain.internal](https://registry.terraform.io/providers/cloudfoundry-community/cloudfoundry/latest/docs/data-sources/domain) | data source |
| [cloudfoundry_org.this](https://registry.terraform.io/providers/cloudfoundry-community/cloudfoundry/latest/docs/data-sources/org) | data source |
| [cloudfoundry_service.this](https://registry.terraform.io/providers/cloudfoundry-community/cloudfoundry/latest/docs/data-sources/service) | data source |
| [cloudfoundry_space.this](https://registry.terraform.io/providers/cloudfoundry-community/cloudfoundry/latest/docs/data-sources/space) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_cloudgov_organization"></a> [cloudgov\_organization](#input\_cloudgov\_organization) | The organization for the cloud.gov account. | `string` | n/a | yes |
| <a name="input_cloudgov_password"></a> [cloudgov\_password](#input\_cloudgov\_password) | The password for the cloud.gov account. | `string` | n/a | yes |
| <a name="input_cloudgov_space"></a> [cloudgov\_space](#input\_cloudgov\_space) | The organization for the cloud.gov account. | `string` | n/a | yes |
| <a name="input_cloudgov_username"></a> [cloudgov\_username](#input\_cloudgov\_username) | The username for the cloudfoundry account. | `string` | n/a | yes |
| <a name="input_github_organization"></a> [github\_organization](#input\_github\_organization) | The organization to use with GitHub. | `string` | `"GSA"` | no |
| <a name="input_github_token"></a> [github\_token](#input\_github\_token) | The token used authenticate with GitHub. | `string` | n/a | yes |
| <a name="input_mtls_port"></a> [mtls\_port](#input\_mtls\_port) | The default port to direct traffic to. Envoy proxy listens on 61443 and redirects to 8080, which the application should listen on. | `number` | `61443` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_name"></a> [name](#output\_name) | n/a |
<!-- END_TF_DOCS -->