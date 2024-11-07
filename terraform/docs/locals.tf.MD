# locals.tf

This is a high level overview of the `locals.tf` file. The locals.tf file itself is heavily commented and will go into detail about individual settings if further information is required.

The locals.tf is the main file that needs to be edited to configure your infrastructure.

###  Global variables

#### project

This variable holds the prefix of your resource names. For example, this project uses `benefit-finder` as a prefix for service names.

#### project_full

This variable is a longer, alternative name used in the project. For example, CircleCI calls this project `benefit-finder-gov`.

#### bootstrap_workspace

The name of the `bootstrap` workspace in Terraform. By default, it's `bootstrap`.

#### global

An object that sets commonly used applications and services (i.e. the WAF and the database), making configuration easier.

#### egress

Settings for the egress proxy that is deployed to the DMZ space.

#### external_applications

Settings for applications that aren't managed by Terraform. This is used to save pipeline variables to dynamically configure the other application.

#### envs

Settings for the majority of the deployment, that is then merged into a single `object`. The sub-object, `all` are configurations for every environment. The other sub-objects should be the name of your Terraform workspaces.