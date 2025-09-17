locals {

  ## The name of the project. Used to name most applications and services.
  ## Default naming convention: ${local.project}-application-name-${terraform.workspace}
  project = "digital-gov"

  ## The full name of the project. If their isn't a longer name, this can be set to
  ## local.project.
  project_full = "${local.project}"

  ## The names of the project's production workspaces. This is used to adjust
  ## settings dynamically throughout this configuration file.
  production_workspaces = ["prod"]

  ## Names of workspaces that should have IP restrictions. This might not
  ## be the inverse of production_workspaces, although you might expect that.
  iprestricted_workspaces = ["dev", "staging"]

  tf_backend = {
    type = "pg"
    name_pattern_psql = "${local.project}-terraform-backend-bootstrap"
    name_pattern_secrets = "${local.project}-pg-secrets-bootstrap"
    space = "prod"
  }


  ## IP addresses allowed to connect, when restricted.
  allowed_ips = base64encode(
     jsonencode([
      "allow 159.142.0.0/16;",
      "allow 2607:6540:2000:800::/64;",
      "allow 2607:6540:2700:800::/64;",
      "allow 2620:0:150:3447:5d77:841e:bc01:5bf4;",
      "allow 2620:0:150:3447:8fca:87e5:da51:4b7b;",
      "allow 2620:0:150:3447:daad:6c9f:fb78:b689;",
      "allow 2620:0:150:3447:faf0:b47d:a67d:5bad;",
      "allow 2620:0:150:3447:6df7:3fdc:64b4:1b83;",
      "allow 2620:0:150:3447:1196:7f61:5aab:fd8f;",
      "allow 2620:0:150:3447:2f92:e6a1:efaa:fb98;",
      "allow 2620:0:150:3447:2772:3f17:a0eb:8566;",
      "allow 2620:0:150:4029:896d:2ddc:8450:efe9;",
      "allow 2620:0:150:4029:de4b:dd85:31cc:6f55;",
      "allow 2620:0:150:4029:a5df:d6e0:fc6c:e16b;",
      "allow 2620:0:150:4029:da15:7695:c137:7767;",
      "allow 2620:0:150:4029:a5bc:cc3f:55f9:6458;",
      "allow 2620:0:150:4029:b8c7:f0d0:941e:de07;",
      "allow 2620:0:150:4029:c9cc:5ce:ec04:eb30;",
      "allow 2620:0:150:4029:f30c:dc1f:6722:b47b;"
    ])
  )

  ## "Common" applications and services that are deployed to every space.
  globals = {
    apps = {
      ## Nginx Web Application Firewall (WAF).
      waf = {

        ## Should the application have access to the internet?
        allow_egress = true

        ## Buildpacks to use with this application.
        ## List buildpacks avalible with: cf buildpacks
        buildpacks = [
          "https://github.com/cloudfoundry/apt-buildpack",
          "nginx_buildpack"
        ]

        ## Command to run when container starts.
        command = "./start"

        ## Ephemeral disk storage.
        disk_quota = 1024

        ## Should SSH be enabled?
        enable_ssh = true

        ## Environmental variables. Avoid sensitive variables.
        environment = {

          RESTRICT_CMS = contains(local.iprestricted_workspaces, terraform.workspace) ? "TRUE" : ""
          ALLOWED_IPS_CMS = contains(local.iprestricted_workspaces, terraform.workspace) ? local.allowed_ips : base64encode(jsonencode([]))

          cms_internal_endpoint = "${local.project}-drupal-${terraform.workspace}.apps.internal"

          ## The OWASP CRS rules for modsecurity.
          CRS_RULES = "coreruleset-4.7.0-minimal.tar.gz"

          ## IP address that are denied access from the static website.
          DENYED_IPS_STATIC = base64encode(jsonencode([]))

          ## The current environment the application is running in.
          ENV = terraform.workspace

          ## Linux "Load Library Path", where system libraries are located. (i.e. libzip, gd, etc)
          LD_LIBRARY_PATH = "/home/vcap/deps/0/lib/"

          ## Ubuntu patch for newer version of mod security.
          MODSECURITY_UPDATE = "libmodsecurity3_3.0.9-1_amd64.deb"

          ## Domains that shouldn't be passed to the egress proxy server (i.e. apps.internal).
          #no_proxy = var.no_proxy
        }

        ## Timeout for health checks, in seconds.
        health_check_timeout = 180

        ## Type of health check.
        ## Options: port, process, http
        health_check_type = "port"

        ## Number of instances of application to deploy.
        instances = 1

        ## Labels to add to the application.
        labels = {
          environment = terraform.workspace
        }

        ## Maximum amount of memory the application can use.
        memory = 128

        ## Addional network policies to add to the application.
        ## Format: name of the application and the port it is listening on.
        network_policies = {
          drupal = 61443
        }

        ## Port the application uses.
        port = 80

        ## Can the application be accessed outside of cloud.gov?
        public_route = true

        ## The source file should be a directory or a zip file.
        source = "${path.cwd}/${var.terraform_working_dir}/applications/nginx-waf"

        ## Templates take templated files and fill them in with sensitive data.
        ## The proxy-to-static.conf has the S3 bucket written to it during
        ## the 'terraform apply' command, before it the files are zipped up and
        ## uploaded to cloud.gov.
        templates = [
          {
            source      = "${path.cwd}/${var.terraform_working_dir}/applications/nginx-waf/nginx/snippets/proxy-to-storage.conf.tmpl"
            destination = "${path.cwd}/${var.terraform_working_dir}/applications/nginx-waf/nginx/snippets/proxy-to-storage.conf"
          },
          {
            source      = "${path.cwd}/${var.terraform_working_dir}/applications/nginx-waf/nginx/snippets/proxy-to-static.conf.tmpl"
            destination = "${path.cwd}/${var.terraform_working_dir}/applications/nginx-waf/nginx/snippets/proxy-to-static.conf"
          },
          {
            source      = "${path.cwd}/${var.terraform_working_dir}/applications/nginx-waf/nginx/snippets/proxy-to-app.conf.tmpl"
            destination = "${path.cwd}/${var.terraform_working_dir}/applications/nginx-waf/nginx/snippets/proxy-to-app.conf"
          }
        ]
      }
      database-backup-bastion = {

          ## Should the application have access to the internet?
          allow_egress = true

          ## Buildpacks to use with this application.
          ## List buildpacks avalible with: cf buildpacks
          buildpacks = [
            "https://github.com/cloudfoundry/apt-buildpack",
            "binary_buildpack"
          ]

          ## Command to run when container starts.
          command = "./start"

          ## Ephemeral disk storage.
          disk_quota = 1024

          ## Should SSH be enabled?
          enable_ssh = true

          ## Environmental variables. Avoid sensitive variables.
          environment = {
            ## Linux "Load Library Path", where system libraries are located. (i.e. libzip, gd, etc)
            LD_LIBRARY_PATH = "/home/vcap/deps/0/lib/"
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
            environment = terraform.workspace
          }

          ## Maximum amount of memory the application can use.
          memory = 64

          services_external = [
            "${local.project}-mysql-${terraform.workspace}",
            "${local.project}-backup-${terraform.workspace}",
            terraform.workspace == local.tf_backend.space ? "${local.project}-terraform-backend-bootstrap" : null
          ]

          ## The source file should be a directory or a zip file.
          source = "../applications/database-backup-bastion"

          space = terraform.workspace

          #stopped = true
        }
    }

    ## Services to deploy in this environment.
    services = {

      ## S3 storage for backups.
      "backup" = {

        ## Applications to bind to this service.
        applications = []

        ## Should a service key be generated for other applications to use?
        service_key = true

        ## The size of the instance to deploy.
        service_plan = "basic"

        ## The type of service to be deployed.
        service_type = "s3"

        ## Tags to add to the service.
        tags = [
          terraform.workspace
        ]
      },

      ## MySQL RDS database.
      "mysql" = {

        ## Applications to bind to this service.
        applications = ["cms"]

        ## The size of the instance to deploy.
        service_plan = contains(local.production_workspaces, terraform.workspace) ? "micro-mysql" : "micro-mysql"

        ## The type of service to be deployed.
        service_type = "aws-rds"

        ## Tags to add to the service.
        tags = [
          terraform.workspace
        ]
      },

      ## Credentials and other sensitive variables.
      "secrets" = {

        ## Applications to bind to this service.
        applications = ["cms", "waf"]

        ## Credentials that should be added to the json blob.
        credentials = [
          "cron_key",
          "hash_salt",
          "gsa_auth_key",
          "newrelic_key"
        ]

        ## The type of service to be deployed.
        service_type = "user-provided"

        ## Tags to add to the service.
        tags = [
          terraform.workspace
        ]
      },

      ## S3 storage for public files for Drupal.
      ## Typically "sites/default/files/"
      "storage" = {

        ## Applications to bind to this service.
        applications = ["cms", "waf"]

        ## Should a service key be generated for other applications to use?
        service_key = true

        ## The size of the instance to deploy.
        service_plan = "basic-public-sandbox"

        ## The type of service to be deployed.
        service_type = "s3"

        ## Tags to add to the service.
        tags = [
          terraform.workspace
        ]
      },

      # S3 storage for the statically generated site.
      "static" = {

        ## Applications to bind to this service.
        applications = ["waf", "cms"]

        ## Should a service key be generated for other applications to use?
        service_key = true

        ## The size of the instance to deploy.
        service_plan = "basic-public-sandbox"

        ## The type of service to be deployed.
        service_type = "s3"

        ## Tags to add to the service.
        tags = [
          terraform.workspace
        ]
      }
    }
  }

  ## The mTLS port the proxy application uses.
  ## Cloudfoundry will automatically redirect connections on this port to local port 8080.
  mtls_port = var.mtls_port

  ## Any applications that are external to this Terraform infrastucture.
  ## In this case, the Drupal application is deployed via a manifest.yml in the Drupal
  ## Github repostitory.
  external_applications = {
    drupal = {

        environement = terraform.workspace

        ## Port is the application listening on.
        port = var.mtls_port
      }
  }

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
      external_applications = try(local.external_applications, [])

      ## The domain name for applications accessable external of cloud.gov.
      external_domain = "app.cloud.gov"

      ## The domain name for applications accessable inside of cloud.gov.
      internal_domain = "apps.internal"

      ## The naming convention/pattern for deployed systems and subsystems.
      ## %s is replaced with the name of the system.
      name_pattern = "${local.project}-%s-${terraform.workspace}"

      ## The name of the cloud.gov organization.
      organization = "gsa-digitalgov-prototyping"

      ## Passwords that are generated for workspaces. By default, it's an empty map.
      ## If one is defined below in a workspace's settings, it will supersed this one.
      passwords = {
          hash_salt = {
            length = 32
          }
          cron_key = {
            length = 32
          }
        }

      ## A copy of the project name, so it gets added to this setting object.
      project = local.project

      ## The name of the current Cloud.gov space.
      space = terraform.workspace
    }

    #################################
    ##
    ##    ____
    ##   |  _ \  _____   __
    ##   | | | |/ _ \ \ / /
    ##   | |_| |  __/\ V /
    ##   |____/ \___| \_/
    ##
    #################################

    dev = merge(
      {
        ## Applications to deploy.
        apps = local.globals.apps
        services = local.globals.services
      },
      {

        ## Passwords that need to be generated for this environment.
        ## These will actually use the sha256 result from the random module.
        passwords = {
          hash_salt = {
            length = 32
          }
          cron_key = {
            length = 32
          }
        }
      }
    )

    #################################
    ##
    ##  ____                _
    ## |  _ \ _ __ ___   __| |
    ## | |_) | '__/ _ \ / _` |
    ## |  __/| | | (_) | (_| |
    ## |_|   |_|  \___/ \__,_|
    ##
    #################################


    prod = merge(
      {
        ## Applications to deploy.
        apps = local.globals.apps
        services = local.globals.services
      },
      {

        ## Passwords that need to be generated for this environment.
        ## These will actually use the sha256 result from the random module.
         passwords = {
          hash_salt = {
            length = 32
          }
          cron_key = {
            length = 32
          }
        }
      }
    )

    #################################
    ##
    ##  __ _
    ## / _\ |_ __ _  __ _  ___
    ## \ \| __/ _` |/ _` |/ _ \
    ## _\ \ || (_| | (_| |  __/
    ## \__/\__\__,_|\__, |\___|
    ##              |___/
    ##
    #################################

    staging = merge(
      {
        ## Applications to deploy.
        apps = local.globals.apps
        services = local.globals.services
      },
      {
        ## Passwords that need to be generated for this environment.
        ## These will actually use the sha256 result from the random module.
        passwords = {
          hash_salt = {
            length = 32
          }
          cron_key = {
            length = 32
          }
        }
      }
    )
  }

  ## Map of the 'all' environement and the current workspace settings.
  env = merge(
    try(
      local.envs.all, {}
    ),
    try(
      local.envs[terraform.workspace], {}
    )
  )

  service_bindings = merge(
    flatten(
      [
        for key, value in try(local.env.services, {}) : {
          "${key}" = value
        }
      ]
    )
  ...)
}

# output "name" {
#   value = local.env
# }
