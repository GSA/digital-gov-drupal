locals {

  ## The name of the project. Used to name most applications and services.
  ## Default naming convention: ${local.project}-application-name-${terraform.workspace}
  project = "digital-gov"

  ## The full name of the project. If their isn't a longer name, this can be set to
  ## local.project.
  project_full = "${local.project}"

  production_space = "prod"

  repository = "GSA/digital-gov-drupal"

  space_pattern = "%s"

## The various environment settings to be deployed.
  envs = {

    ## Every environment gets settings in 'all'.
    all = {

      ## The API URL for cloud.gov.
      api_url = "https://api.fr.cloud.gov"

      ## These values are defaults values when options aren't configured in the application block.
      defaults = {

        ## The default size of the containers ephemeral disk.
        disk_quota = 2048

        ## Is SSH enabled on the container by default?
        enable_ssh = true

        ## The default health check timeout.
        health_check_timeout = 60

        ## Default method of performing a health check.
        ## Valid options: "port", "process", or "http"
        ## https://docs.cloudfoundry.org/devguide/deploy-apps/healthchecks.html
        health_check_type = "port"

        ## Default number of application instances to deploy.
        instances = 1

        ## Default amount of memory to use memory to use for an application.
        memory = 64

        port = 8080

        ## The default cloudfoundry stack to deploy.
        ## https://docs.cloudfoundry.org/devguide/deploy-apps/stacks.html
        stack = "cflinuxfs4"

        ## Is the application stopped by default?
        stopped = false

        ## Default CloudFoundry deployment strategy.
        ## Valid optons: "none", "standard", or "blue-green".
        ## https://docs.cloudfoundry.org/devguide/deploy-apps/rolling-deploy.html
        strategy = "none"

        ## Default wait time for an application to start.
        timeout = 300
      }

      ## Configuration settings for the egress proxy application.
      # egress = local.egress

      ## External application based on the Terraform workspace being used.
      external_applications = {}

      ## The domain name for applications accessable external of cloud.gov.
      external_domain = "app.cloud.gov"

      ## The domain name for applications accessable inside of cloud.gov.
      internal_domain = "apps.internal"

      ## The naming convention/pattern for deployed systems and subsystems.
      ## %s is replaced with the name of the system.
      name_pattern = "${local.project}-%s-${terraform.workspace}"

      ## The name of the cloud.gov organization.
      organization = var.cloudgov_organization

      ## Passwords that are generated for workspaces. By default, it's an empty map.
      ## If one is defined below in a workspace's settings, it will supersed this one.
      passwords = {
        # test = {length = 32}
        hash_salt = {length = 32}
      }

      ## A copy of the project name, so it gets added to this setting object.
      project = local.project

      ## The name of the current Cloud.gov space.
      space = "${terraform.workspace}"
    }

    ##
    ##
    ## The bootstrap workspace.
    ## Used to initialize gobal/project wide applications/services.
    ##
    ##

    bootstrap = {
      secrets = {
        PGDATABASE = {
          encrypted = false
          key = "terraform-backend-db_name"
        }
        PGHOST = {
          encrypted = false
          key = "terraform-backend-host"
        }
        PGPASSWORD = {
          encrypted = false
          key = "terraform-backend-password"
        }
        PGPORT = {
          encrypted = false
          key = "terraform-backend-port"
        }
        PG_CONN_STR = {
          encrypted = false
          key = "terraform-backend-uri"
        }
        PGUSER = {
          encrypted = false
          key = "terraform-backend-username"
        }
        CF_USER = {
          encrypted = false
          key = "cf_user"
        }
        CF_PASSWORD = {
          encrypted = false
          key = "cf_password"
        }
        CF_ORG = {
          encrypted = false
          key = "cf_org"
          value = var.cloudgov_organization
        }
        PROJECT = {
          encrypted = false
          key = "project"
          value = local.project
        }
        TF_BACKEND_SPACE = {
          encrypted = false
          key = "tf_backend_space"
          value = local.production_space
        }
        TF_BASTION = {
          encrypted = false
          key = "tf_bastion"
          value = "${local.project}-tf-bastion-bootstrap"
        }
        gsa_auth_development_key = {
          encrypted = false
          key = "gsa_auth_development_key"
          value = var.gsa_auth_development_key
        }
        gsa_auth_production_key = {
          encrypted = false
          key = "gsa_auth_production_key"
          value = var.gsa_auth_production_key
        }
        hash_salt = {
          encrypted = false
          key = "hash_salt"
        }
      }

      services = {
        terraform-backend = {
          ## Applications to bind to this service.
          applications = [ "tf-bastion" ]

          ## The size of the instance to deploy.
          service_plan = "micro-psql"

          ## The type of service to be deployed.
          service_type = "aws-rds"

          ## Tags to add to the service.
          tags = [
            terraform.workspace
          ]
        }
        # pipeline-space-deployer = {
        #   ## Applications to bind to this service.
        #   applications = [ "tf-bastion" ]
          
        #   ## Create a service account.
        #   service_type = "cloud-gov-service-account"

        #   ## The type of service to be deployed.
        #   service_plan = "space-deployer"

        #   spaces = ["dev", "staging", "prod"]

        #   ## Tags to add to the service.
        #   tags = [
        #     terraform.workspace
        #   ]
        # }
      }

      space = local.production_space

      variables = {
        "UBUNTU_VERSION" = {
          key = "UBUNTU_VERSION"
          value = "jammy"
        }
        "MODSECURITY_NGINX_VERSION" = {
          key = "MODSECURITY_NGINX_VERSION"
          value = "1.0.3"
        }
      }
    }

    "${local.production_space}" = {
      apps = {
        tf-bastion = {

          ## Should the application have access to the internet?
          allow_egress = true

          ## Buildpacks to use with this application.
          ## List buildpacks avalible with: cf buildpacks
          buildpacks = [
            "https://github.com/cloudfoundry/apt-buildpack",
            "binary_buildpack"
          ]

          ## Command to run when container starts.
          command = "/home/vcap/app/start"

          ## Ephemeral disk storage.
          disk_quota = 1024

          ## Should SSH be enabled?
          enable_ssh = true

          ## Environmental variables. Avoid sensitive variables.
          environment = {
            CF_ORG = var.cloudgov_organization
            OPENTOFU_VERSION = "1.8.7"
            PERL5LIB = "/home/vcap/deps/0/apt/usr/share/perl5/"
          }

          ## Timeout for health checks, in seconds.
          health_check_timeout = 180

          ## Type of health check.
          ## Options: port, process, http
          health_check_type = "process"

          ## Number of instances of application to deploy.
          instances = 1

          ## Labels to add to the application.
          labels = {
            environment = "prod"
          }

          ## Maximum amount of memory the application can use.
          memory = 512

          ## Addional network policies to add to the application.
          ## Format: name of the application and the port it is listening on.
          network_policies = {}

          ## Port the application uses.
          #port = 0

          ## Can the application be accessed outside of cloud.gov?
          public_route = false

          ## The source file should be a directory or a zip file.
          source = "../applications/tf-bastion"

          space = local.production_space

          #stopped = true

          ## Templates take templated files and fill them in with sensitive data.
          templates = []
        }
      }
    }
  }

  ## Map of the 'all' environement and the current workspace settings.
  env = merge(try(local.envs.all, {}), try(local.envs.bootstrap, {}))
}
