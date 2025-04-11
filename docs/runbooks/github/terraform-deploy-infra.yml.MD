### Runbook for `terraform-deploy-infra.yml`

#### Introduction
This runbook is for the GitHub Actions workflow file `terraform-deploy-infra.yml`. The workflow is designed to update infrastructure through a series of steps that include environment setup, dependency installation, cloud login, repository checkout, and Terraform operations like init, plan, validate, and apply. The code handles multiple deployment environments, such as development, staging, and production, by setting up the appropriate Cloud Foundry space (`CF_SPACE`). This runbook breaks down each step of the workflow and provides troubleshooting tips.

#### Technical Breakdown

##### Workflow Overview
The workflow `terraform-deploy-infra.yml` is structured to manage the deployment of infrastructure changes. It consists of a primary job `updateInfrastructure` and a secondary job `stopBastion`. The `updateInfrastructure` job is responsible for the main deployment process, while `stopBastion` ensures a cleanup action is performed.

##### Environment Setup
- **Checkout**: The workflow begins with a checkout action to clone the repository.
  
- **Set Environment Variables**:
  - `Set env.BRANCH`: Determines the branch and sets the `BRANCH` and `CF_SPACE` environment variables accordingly.
  - `Set repo name`: Sets the repository name for later use.

- **Install Dependencies**:
  - `Install basic dependancies`: Runs a script to install essential dependencies.
  - `Install Cloudfoundry CLI`: Installs the Cloudfoundry CLI to manage cloud operations.

##### Cloud.gov Login and Bastion Management
- **Cloud.gov login**: Uses secrets to authenticate and sets the target cloud space.
- **Start Bastion**: Starts the bastion instance which will be used for remote commands.
- **Cloud.gov bastion git checkout**: Clones the repository into the bastion environment.

##### Terraform Operations
- **Build nginx WAF Plugin**: Builds required plugins and sets configurations.
- **Configure Terraform**: Configures Terraform variables and deploys them to the bastion instance.
- **Terraform Init**: Initializes Terraform with the workspace specified by `CF_SPACE`.
- **Terraform Validate**: Validates the Terraform configuration files.
- **Terraform Plan**: Generates a plan for the infrastructure changes.
- **Terraform Apply**: Applies the changes to the infrastructure, auto-approving any prompts.

##### Cleanup
- **Stop Bastion**: Ensures the bastion instance is stopped after the deployment steps are completed.

#### Troubleshooting

- **Error: Unable to find a repository**: Verify that the repository URL is correct and that the GitHub token has the necessary permissions to access it.
- **Error: Cloud Foundry CLI not installed**: Ensure the `deb-cf-install.sh` script successfully installs the Cloudfoundry CLI.
- **Error: Unauthorized access**: Check the secrets used in the `Cloud.gov login` section to ensure they contain valid credentials.
- **Error: Terraform commands fail**: Confirm that the `CF_SPACE` is properly configured to match the intended deployment environment. Also, ensure that the `terraform` directory structure and variable files are correctly set up.
- **Error: Bastion instance does not start**: Check the Cloud Foundry CLI commands within `startBastion` to ensure the correct app name is being referenced (e.g., `${TF_BASTION}`).
- **Error: Script execution fails**: Review the scripts (`cloud-gov-remote-command.sh`, `cloud-gov-scp-file.sh`, etc.) to ensure correct permissions and that they handle all edge cases like network interruptions or remote server errors.

#### Example Scenarios

- **Scenario: Branch Development**: When the `develop` branch or any branch with `deploydev` in its name is checked out, the `CF_SPACE` is set to `dev`, indicating a development deployment environment.
- **Scenario: Main Branch**: When the `main` branch is checked out, the `CF_SPACE` is set to `prod`, indicating a production deployment environment.
- **Scenario: Staging Branch**: When the `stage` branch, `release/*`, `hotfix/*`, or any branch with `deploystaging` in its name is checked out, the `CF_SPACE` is set to `staging`, indicating a staging deployment environment.
