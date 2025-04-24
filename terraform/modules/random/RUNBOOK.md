### Runbook for Random Module

#### Introduction

The provided code consists of Terraform configurations for managing passwords across different workspaces based on specified conditions. It includes handling password generation, hashing, expiration, and per-workpace configurations. This runbook will offer a technical write-up of the code with insights on how to set up and troubleshoot the password management system.

#### Technical Breakdown

**Main Configuration File: main.tf**

**1. Local Variables:**

The `locals` block generates a map named `passwords` by merging other maps derived from iterating through `var.names` and `var.passwords`. This map is built only for elements that meet specified conditions like `value.per_workspace` being true.

**2. Resource Definitions:**

- **time_rotating**: This resource, with a `for_each` structure, manages time-based rotation of passwords. Certain passwords are rotated according to settings with expirations greater than zero.
  
- **time_static**: The `time_static` resource retains configurations for static passwords that don't require rotation and meet the conditions specified within the `for_each` block.

- **random_password**: Depending upon the conditions set in `var.per_workspace`, random passwords are generated using specific settings like length, case sensitivities, and special characters. The generated passwords are then mapped to the static or rotating time blocks as necessary.

**Output Configuration File: outputs.tf**

- This file defines an output block named "results" that compiles a map with various hash values (MD5, SHA1, SHA256, SHA512) for the generated passwords. The mapping depends on the workspace setting `var.per_workspace` - if it's true, then it uses multiple workspace configurations; otherwise, it relies on the single workspace configurations.

**Variable Configuration File: variables.tf**

- **names**: Defines a list of string to provide unique names for multiple workspace resources.
- **passwords**: A map of objects that specifies password settings including character requirements, length, and expiration details.
- **per_workspace**: A Boolean variable that defines whether password generation is on a per-workspace basis or not.

#### Troubleshooting

- **Error: Missing or Incorrect Variable Input**
    - Ensure that `var.names`, `var.passwords`, and `var.per_workspace` are correctly set before executing the Terraform code. Missing or incorrectly formatted input can lead to undefined variables, which will prevent the code from running correctly.
    - **Solution**: Verify the input variables in your Terraform configuration, especially the content of the `var.passwords` object, to ensure it meets the conditions specified in the `locals` block and resource definitions.

- **Error: Invalid Condition or Early Expiration**
    - If you find that passwords are expiring or being rotated unexpectedly, it may indicate that the conditions or `expiration_days` in your `var.passwords` configurations are not properly defined.
    - **Solution**: Cross-reference the `expiration_days` values set in `var.passwords` to guarantee they are set appropriately within the `locals` block and `time_rotating` resource for each defined workspace.

- **Error: Missing Dependencies in Output**
    - If you encounter issues with missing hash outputs for the passwords, ensure that the dependencies (i.e., either `time_rotating.single` or `time_static.single`, or the `multiple` equivalents) are properly defined and available when the output block is evaluated.
    - **Solution**: Carefully check the `keepers` block within `random_password` to ensure that it correctly maps each key to the corresponding `time_rotating` or `time_static` time resource. Applied correctly, this will ensure that the passwords are hashing and tracking correctly within the output block.
