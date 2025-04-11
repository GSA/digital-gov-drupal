### Runbook for Bootstrap

#### Introduction

This runbook is designed to provide a guide to understanding and troubleshooting the bootstrapping processes for a new Cloud.gov project as outlined in the provided code document. The codebase includes scripts and Terraform configurations that detail the creation of service accounts, management of environments, and the deployment of services and applications within a Cloud.gov organization. This runbook will walk through each component's purpose, interactions, and critical troubleshooting steps.

The base configuration of this file bootstraps a single Postgres RDS instance service (`terraform-backend`), used for [Terraform state storage](https://developer.hashicorp.com/terraform/language/backend/pg), and a single bastion application (`terraform-bastion`), used for interating with `terraform-backend` database.

The `terraform-bastion` application has the `psql-client` and `OpenTofu` installed by default.  `OpenTofu` is an open source fork of `Terraform`, before `Terraform` changed their licensing.
  - The application is configured in `../applications/tf-bastion`.
  - The `OpenTofu` version is configured in `locals.tf` by modifying the `OPENTOFU_VERSION` environmental variable.

#### Technical Breakdown

##### 1. Script: `create_service_account.sh`

###### Purpose
  - The script is used to create a new service account in a new Cloud.gov organization for use in automated workflows such as deploying applications via a CI/CD pipeline.

###### Technical Details
  - The script starts by creating a service account named `pipeline`.
  - Retrieves the active organization name using `cf target`.
  - Fetches the username for a service key from the created service account.
  - Assigns Space Developer roles to the service account across all spaces in the organization.

##### 2. Terraform Configuration: `data.tf`

###### Purpose
  - Terraform configurations in `data` resources are used to define and query Cloud.gov environments and resources such as organizations, spaces, domains, and services.

###### Technical Details
  - Defines `data` blocks for Cloudfoundry environments like organization, spaces, and internal/external domains.
  - Utilizes data resources to query existing Cloud.gov configurations and validate presence of necessary resources.

##### 3. Terraform Configuration: `locals.tf`

###### Purpose
  - This file contains local variables, settings, and configurations tailored to the project, including organization name, environment settings, service configurations, and general project parameters.

###### Technical Details
  - Defines variables and values specific to the project, such as the Cloud.gov organization, environment variables, and application-related configurations.
  - Utilizes the `merge` function to combine settings of multiple environments (e.g., dev, staging, prod) and declares global defaults applicable to all environments.

##### 4. Main Terraform Configuration: `main.tf`

###### Purpose
  - Orchestrates the creation and management of services and applications in Cloud.gov through Terraform resources by linking to module configurations.

###### Technical Details
  - Defines modules for handling creation of services and applications.
  - Utilizes sourced provider definitions and environment variables defined in `locals.tf`.
  - Deploys services and applications using modules for creating instances and binding them to appropriate service credentials.

##### 5. Provider Configuration: `provider.tf`

###### Purpose
  - Configures the Cloud.gov and GitHub providers necessary for Terraform operations using environment-specific credentials.

###### Technical Details
  - Sets required Terraform version and required providers.
  - Defines providers for authenticating to Cloud.gov and GitHub using user-provided variables for API URLs, usernames, passwords, and tokens.

##### 6. Variables Configuration: `variables.tf`

###### Purpose
  - Contains the definition of input variables required for Terraform configurations, such as Cloud.gov and GitHub credentials.

###### Technical Details
  - Defines variables such as cloud.gov organization name, space details, GitHub organization, and secure authentication tokens.

#### Troubleshooting

##### 1. Service Account Creation Issues
  - **Problem:** Experience errors in creating the `space-deployer` service account or assigning roles.
  - **Solution:** Ensure that the Cloud.gov CLI (`cf`) is correctly configured with proper credentials and permissions. Check if the organization name retrieval command is accurately fetching the active organization.

###### 2. Terraform Environment Resource Queries

  - **Problem:** Missed queries or the inability to use Cloudfoundry data sources to retrieve and validate the presence of resources.
  - **Solution:** Validate configuration in `data.tf`. Ensure that resource names and identifiers are correct and match the environment being configured. Use `terraform console` to test and fetch the correct values.

###### 3. Application Deployment Failures

  - **Problem:** Encounter failed deployments of applications due to incorrect configurations or services not binding properly.
  - **Solution:** Refine the Terraform module configurations in `main.tf`. Verify that all necessary environment variables and secrets are properly configured and sourced from `locals.tf` and `secrets` files. Check for any deployment errors and debug using `cf logs` and `terraform show`.

###### 4. Provider Errors

  - **Problem:** Authentication errors or inability to communicate with Cloud.gov or GitHub.
  - **Solution:** Double-check API URLs, usernames, passwords, and tokens against the values defined in `provider.tf`. Ensure that the required Terraform and provider versions match the declared versions in the code.

