### Runbook: Github Module

#### Introduction
This runbook provides a step-by-step guide to manage secrets and variables in a GitHub repository using Terraform. The code involves Terraform configuration files (`main.tf` and `variables.tf`), and a provider specification file (`provider.tf`) to create and manage cryptographic secrets and environment variables in a GitHub repository. The configuration is designed to work with the GitHub DevOps provider.

#### Technical Breakdown

##### Terraform Configuration Overview

- **Data Source: `github_repository`** (`main.tf`)
  - Used to define the GitHub repository details by referencing a variable (`var.repository`).
  - Example:
    ```terraform
    data "github_repository" "this" {
      full_name = var.repository
    }
    ```
- **Resource: `github_actions_secret`** (`main.tf`)
  - This resource is defined to manage secrets in the GitHub repository. Each secret is defined by a key-value pair.
  - The `plaintext_value` corresponds to the value stored in the `var.secrets` map when `encrypted` is set to `false`; otherwise, it is `null`.
  - The `encrypted_value` holds the encrypted value if `encrypted` is `true`. Otherwise, it is `null`.
  - Example:
    ```terraform
    resource "github_actions_secret" "this" {
      for_each = { for key, value in try(var.env.secrets, []) : key => value }
      repository       = data.github_repository.this.name
      secret_name      = each.key
      plaintext_value = !try(each.value.encrypted, false) ? try(var.secrets[each.value.key], null) : null
      encrypted_value  = try(each.value.encrypted, false) ? try(var.secrets[each.value.key], null) : null
    }
    ```

- **Resource: `github_actions_variable`** (`main.tf`)
  - This resource is used to define and manage environment variables in the GitHub repository.
  - Each variable is associated with a `repository` and has a `value`.
  - Example:
    ```terraform
    resource "github_actions_variable" "this" {
      for_each = { for key, value in try(var.variables, []) : key => value }
      repository    = data.github_repository.this.name
      variable_name = each.key
      value         = each.value
    }
    ```

- **Provider Configuration** (`provider.tf`)
  - Defines the GitHub provider that Terraform uses to interface with the GitHub DevOps API.
  - Requires a GitHub organization name (`var.github_organization`) and a token (`var.github_token`) for authentication.
  - Example:
    ```terraform
    provider "github" {
      owner = var.github_organization
      token = var.github_token
    }
    ```

- **Inputs and Variables** (`variables.tf`)
  - Defines the input variables used in the Terraform configuration, including `env`, `github_organization`, `github_token`, `repository`, `secrets`, and `variables`.
  - Example:
    ```terraform
    variable "env" {
      description = "The settings object for this environment."
      type = object({
        ...
      })
    }
    ```

###### Troubleshooting

- **Terraform Apply Fails Due to Unmet Requirements:**
  - **Error:** "Terraform required a newer version of Terraform or provider versions are not compatible."
  - **Resolution:** Ensure Terraform is up to date (`version > 1.7`), and the `github` provider version matches the expected range (`~> 6.0`).

- **Error Handling Secrets:**
  - **Error:** "Secrets cannot be resolved to a value."
  - **Resolution:** Check the `env.secrets` and `secrets` variables are properly defined and contain the correct key-value pairs.

- **Mismanaging Authentication:**
  - **Error:** "Insufficient permissions or invalid token."
  - **Resolution:** Verify that the `github_token` has the necessary repository permissions and is valid.

- **Encrypt or Decrypt Issues:**
  - **Error:** "Value could not be decrypted or is not in the expected format."
  - **Resolution:** Ensure that the `encrypted` flag is set correctly for each `secret` in the `env.secrets` mapping and that the `secrets` variable contains the correctly formatted values.

- **Name Resolution Issues:**
  - **Error:** "Repository or secret names do not conform to GitHub specifications."
  - **Resolution:** Check that names used are properly formatted and conform to GitHub's naming rules.

- **General Errors:**
  - **Error:** "Terraform state management issues."
  - **Resolution:** Clear the Terraform state with `terraform state rm` or use state backup to manage inconsistencies.
