## Runbook for Applications Module

### Introduction

The provided code consists of a Terraform infrastructure deployment that sets up and manages Cloud Foundry applications, including their service bindings, routes, and network policies. The structure is organized into multiple files, each serving a specific role in the configuration process. Key components include service lookups, application resource creation, route management, and network policy setup.

### Technical Breakdown

#### 1. Overview of Files

- **main.tf**: Contains Terraform configurations for managing password settings and rotations.
- **outputs.tf**: Specifies the output of generated passwords and their respective hash values (MD5, SHA1, SHA256, SHA512).
- **variables.tf**: Defines input variables used by the Terraform configurations.

#### 2. Detailed Technical Writeup

- **Service Lookups and Externally Deployed Services**:

  The code in `data.tf` includes a service lookup module to reference and manage external services. For each unique external service, a `cloudfoundry_service_instance` data source dynamically queries for the GUID of the service instance, ensuring each service instance is referenced uniquely:

  ```tf
  locals {
    services_external = toset(
      compact(
        distinct(
          flatten(
            [
              for value in try(var.env.apps, {}) : [
                try(value.services_external, [])
              ]
            ]
          )
        )
      )
    )
  }

  data "cloudfoundry_service_instance" "this" {
    for_each = try(local.services_external, [])
    name_or_id  = each.value
    space       = try(var.cloudfoundry.space.id, null)
  }
  ```

- **Application Resource Creation**:

  The `main.tf` file manages the application lifecycle, including buildpacks, Docker images, service bindings, and route configurations. For each application defined in the environment variable `var.env.apps`, the `cloudfoundry_app` resource is created with various attributes like name, memory, disk quota, and health checks:
  
  ```tf
  resource "cloudfoundry_app" "this" {
    for_each = { for key, value in try(var.env.apps, {}) : key => value }
    buildpack = try(each.value.buildpack, null)
    buildpacks = try(each.value.buildpacks, null)
    command = try(each.value.command, null)
    disk_quota = try(each.value.disk_quota, try(var.env.defaults.disk_quota, 1024))
    ... 
    strategy = try(each.value.strategy, try(var.env.defaults.strategy, "none"))
    timeout = try(each.value.timeout, try(var.env.defaults.timeout, 60))
  }
  ```

- **Service Bindings and External Services**:

  Service bindings are attached to Cloud Foundry applications, determining which service each application connects to. The code dynamically binds services to applications based on the `var.env.services` variable. Custom logic provides bindings for `user-provided` services as well:

  ```tf
  dynamic "service_binding" {
    for_each = { 
      for svc_key, svc_value in try(var.env.services, {}) : svc_key => svc_value
      if contains(svc_value.applications, each.key) && svc_value.service_type != "user-provided"
    }
    content {
      service_instance = var.services.instance[service_binding.key].id
    }
  }

  dynamic "service_binding" {
    for_each = { 
      for svc_key, svc_value in try(var.env.services, {}) : svc_key => svc_value
      if contains(svc_value.applications, each.key) &&
         svc_value.service_type == "user-provided"
    }
    content {
      service_instance = var.services.user_provided[service_binding.key].id
    }
  }
  ```

  External services that are not deployed by the environment can also be bound to applications:

  ```tf
  dynamic "service_binding" {
    for_each = try(local.services_external, [])
    content {
      service_instance = data.cloudfoundry_service_instance.this[service_binding.value].id
    }
  }
  ```

- **Route Management**:

  For both external and internal routes, the `routes.tf` file manages the creation of `cloudfoundry_route` resources. External routes expose applications to the public internet, while internal routes allow communication within the private network:

  ```tf
  resource "cloudfoundry_route" "external" {
    for_each = { for key, value in try(var.env.apps, {}) : key => value
      if value.public_route && try(value.port, -1) != -1
    }
    space = try(var.cloudfoundry.spaces[each.value.space].id, var.cloudfoundry.space.id)
    hostname = format(var.env.name_pattern, each.key)
    target {
      app = cloudfoundry_app.this[each.key].id
      port = 0
    }
  }

  resource "cloudfoundry_route" "internal" {
    for_each = {
      for key, value in try(var.env.apps, {}) : key => value
      if !value.public_route && try(value.port, -1) != -1
    }
    space = try(var.cloudfoundry.spaces[each.value.space].id, var.cloudfoundry.space.id)
    hostname = format(var.env.name_pattern, each.key)
    target {
      app = cloudfoundry_app.this[each.key].id
      port = 0
    }
  }
  ```

- **Network Policies**:

  Network policies are configured in `networking.tf` to manage traffic between different applications and cloud spaces. This includes ingress and egress proxy policies, which ensure proper network pathways are established:
  
  ```tf
  resource "cloudfoundry_network_policy" "ingress_proxy" {
    for_each = {
      for key, value in try(var.env.apps, []) : value.name => value
      if try(value.network_policy, null) != null &&
         try(var.cloudfoundry.external_applications[value.network_policy.name].id, null) != null
    }
    policy {
      source_app = cloudfoundry_app.this[each.key].id
      destination_app = var.cloudfoundry.external_applications[each.value.network_policy.name].id
      protocol = try(var.env.apps[each.key].network_policy_app.protocol, "tcp")
    }
  }
  ```

### 3. Troubleshooting

When encountering issues, ensure that the variables (e.g., `var.env`, `var.services`, etc.) are correctly set up in your Terraform configuration. Misconfigured variable inputs can lead to unexpected behavior or failures.

Common issues include:

- **Service Instance Not Found:** Verify that all external service instances exist in the environment and that their names are correctly referenced.
- **Incorrect Resource Binding:** Double-check your `var.env.services` to ensure services are correctly bound to the respective applications.
- **Route Configuration Errors:** Verify that the `hostnames` and `cors` configurations are correctly specified for external and internal routes.
- **Network Policy Setup:** Check the `cloudfoundry_network_policy` configuration to make sure the `source_app` and `destination_app` IDs are correctly set and that applications are able to communicate as expected.
