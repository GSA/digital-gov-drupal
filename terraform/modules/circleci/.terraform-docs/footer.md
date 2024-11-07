## Examples

```terraform
module "circleci" {
  source = "./modules/circleci"
  
  env = local.env
  services = local.services
  secrets = local.secrets
  schedules = local.env.circleci.schedules
}
```
