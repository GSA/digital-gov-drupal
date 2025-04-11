## Runbook for Service Module

### Introduction
This runbook is for the service module which is designed to manage and create service resources in Cloud Foundry. The codebase includes configuration files for local variables, resource definitions, output specifications, and provider requirements. The Terraform state includes the definition of service instances and user-provided services, with conditions on creating service keys, based on various input variables.

### Technical Breakdown

#### 1. Overview of Files

- **main.tf**: Contains Terraform configurations for cloud resources.
- **output.tf**: Contains the outputs that will be presented after Terraform applies.
- **providers.tf**: Lists the providers that Terraform requires, specifying versions.
- **variables.tf**: Defines the variables Terraform will use, including defaults and descriptions.

#### 2. Detailed Technical Writeup

##### Resource Definitions in **main.tf**
- **Service Instances**: Defined using `cloudfoundry_service_instance`. Key parameters include `name`, `json_params`, `replace_on_params_change`, `replace_on_service_plan_change`, `space`, and `service_plan`. A service instance is created for each service under the `env.services` that is neither a "user-provided" service nor skipped if the `skip_service_instances` boolean variable is true.
  
  ```terraform
  resource "cloudfoundry_service_instance" "this" {
    for_each = {
      for key, value in try(var.env.services, {}) : key => value
      if !var.skip_service_instances &&
         value.service_type != "user-provided"
    }
    ...
  }
  ```

- **Service Keys**: Defined using `cloudfoundry_service_key`. Service keys are only created for services that are not "user-provided" and where the `value.service_key` attribute is set to true. 

  ```terraform
  resource "cloudfoundry_service_key" "this" {
    for_each = {
      for key, value in try(var.env.services, {}) : key => value
      if !var.skip_service_instances &&
         value.service_type != "user-provided" &&
         try(value.service_key, false)
    }
    ...
  }
  ```

- **User-Provided Services**: Defined using `cloudfoundry_user_provided_service`. These are created based on the `local.credentials` local variable construction. This local variable handler collects service configuration data and merges credentials from `var.secrets`.

  ```terraform
  resource "cloudfoundry_user_provided_service" "this" {
    for_each = local.credentials
    ...
  }
  ```

##### Variables in **variables.tf**
The Terraform variables include detailed settings that govern the deployment of services in Cloud Foundry:
- `cloudfoundry`: An object that holds essential information on cloud domain settings, applications, and services.
- `env`: An object representing the environment, with settings like the `api_url`, `name_pattern`, `organization`, `services`, and more. `services` is a map holding various details for creating service instances.
- `skip_service_instances`: A boolean that controls whether to skip the creation of service instances for resources marked as non-user-provided.
- `secrets`: A variable to store sensitive data, which is marked as sensitive to prevent leaks.

##### Output in **output.tf**
- `results`: An output structure that will display results for service instances, user-provided services, and service keys. These outputs compile resources created in the Cloud Foundry environment into readable outcomes.

##### Providers in **providers.tf**
- Cloud Foundry provider is defined with specific required provider versions for ensuring compatibility and functionality.

### Troubleshooting

#### Common Issues and Solutions
- **Resource Creation Error**: If a certain resource fails to be created, check the `var.env.services` configuration and ensure all required fields are correctly passed.
- **Missing Secrets**: If sensitive information is not encrypted or passed properly, you may encounter failed creations or warnings. Validate the `secrets` variable inputs and the settings around sensitive handling.
- **Provisioning Errors**: If provisioning fails due to Cloud Foundry's side constraints or cloud infrastructure issues, the error message should guide you. Ensure API URLs and permissions are correct.

#### Debugging
- **Terraform Logs**: Use `terraform apply --debug` to inspect detailed logs that can provide insight into what is going wrong during resource creation.
- **Variable Verification**: Verify the input variables are set correctly by running `terraform plan -var-file=<VAR_FILE>` and checking the output.
