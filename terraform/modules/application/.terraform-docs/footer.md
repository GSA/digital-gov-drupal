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

Valid options are the attributes for the [cloudfoundry_app](https://registry.terraform.io/providers/cloudfoundry-community/cloudfoundry/latest/docs/resources/app) resource.

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