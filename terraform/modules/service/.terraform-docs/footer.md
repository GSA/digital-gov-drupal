## Examples

### Basic
```terraform
module "services" {
  source = "./modules/service"

  cloudfoundry = local.cloudfoundry
  env = local.env
}
```

### Advanced

This advanced example will first generate service instances, such as RDS, along with other defined services, except for the `user defined` services. `User defined` services are useful for providing variables at runtime to applications. The issue is that until a service, such as RDS is deployed, their isn't a username and password created for that instance.

The first step is to initalize any services that are not `user defined`, but setting `skip_user_provided_services` to `true`.

```terraform
module "services" {
  source = "./modules/service"

  cloudfoundry = local.cloudfoundry
  env = local.env

  skip_user_provided_services = true
}
```

After the services are generated, another module block can be defined, which will pass a merged `map(string)` called `secrets`, that have the various information that is to be added to the `user defined` service. Setting the `skip_service_instances` to `true` will prevent the module from trying to redploy any non `user defined` service.

```terraform
module "secrets" {
  source = "./modules/service"

  cloudfoundry = local.cloudfoundry
  env = local.env

  secrets = local.secrets
  skip_service_instances = true
}
```

## Runbook

For a deeper breakdown of this module, you can read the full runbook for this module. A runbook is a collection of documented procedures, guidelines, and best practices used by teams, typically in IT operations and system administration, to handle routine processes and incidents efficiently. Runbooks provide step-by-step instructions and checklists to troubleshoot problems, maintain systems, and manage various tasks.

[Runbook](RUNBOOK.md)