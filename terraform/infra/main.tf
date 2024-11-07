module "random" {
  source    = "../modules/random"
  names     = local.workspaces
  passwords = local.env.passwords
}

## Currently broken in CF provider v0.53.1.
# resource "cloudfoundry_space_asgs" "trusted_local_networks_egress" {
#   space = data.cloudfoundry_space.this.id
#   running_asgs = [ 
#     data.cloudfoundry_asg.trusted_local_networks_egress.id,
#     data.cloudfoundry_asg.public_networks_egress.id
#   ]
#   staging_asgs = []
# }

## The instanced services (i.e. RDS, S3, etc.) get created first.
## This allows their credentials to be injected into "user-provided" services (JSON blobs), if needed.
module "services" {
  source = "../modules/service"

  cloudfoundry                = local.cloudfoundry
  env                         = local.env
  skip_user_provided_services = true

  depends_on = [
    module.random
  ]
}

module "secrets" {
  source = "../modules/service"

  cloudfoundry           = local.cloudfoundry
  env                    = local.env
  skip_service_instances = true
  secrets                = local.secrets

  depends_on = [
    module.random
  ]
}

module "applications" {
  source = "../modules/application"

  cloudfoundry = local.cloudfoundry
  env          = local.env
  secrets      = local.secrets
  services     = local.services

  depends_on = [ module.services ]
}

# output "name" {
#   value = merge(
#     flatten(
#       [ 
#         for service in try(local.env.services, {}) : {
#           "${service.name}" = service
#         }
#       ]
#     )
#   ...)
# }