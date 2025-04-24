### Runbook for `generate-static.yml`

#### Introduction
This runbook is for the GitHub Action workflow defined in the `generate-static.yml` file, which is designed to generate a static site. The workflow is triggered by a call from another workflow and requires a `CF_SPACE` input parameter for execution. The process includes logging into the Cloudfoundry environment and ensuring dependencies are installed and updated.

#### Technical Breakdown

The workflow consists of several steps aimed at ensuring that the static site generation process runs smoothly within a specified Cloudfoundry space. Here is a detailed breakdown of each step involved in the process:

1. **Trigger**: 
   - The workflow is triggered via a `workflow_call` event.
   - The `on` keyword indicates the workflow is invoked another workflow’s call action.
   - An `inputs` section requires a `CF_SPACE` input, which is essential for subsequent steps in the workflow.

2. **Job Definition**: 
   - The job named `generateStatic` is set to run on the `ubuntu-latest` runner.
   - The job runs based on a condition defined by `if: contains(vars.GENERATE_STATIC_SITE_ON_CRON_SPACES, inputs.CF_SPACE)`.
   - If the condition is met, the job proceeds with the defined steps.

3. **Steps**:
   - **Checkout**: 
     - Uses `actions/checkout@v4` to check out the code to the workspace.
   - **Install Basic Dependencies**: 
     - A shell script is executed using `./scripts/pipeline/deb-basic-deps.sh` to install basic dependencies required for the process.
   - **Install Cloudfoundry CLI**: 
     - Another shell script is executed with `./scripts/pipeline/deb-cf-install.sh` to install the Cloudfoundry CLI, which the workflow uses to manage services in Cloudfoundry.
   - **Cloud.gov Login**: 
     - The `Cloud.gov login` step performs several operations:
     - Utilizes environment variables like `CF_USER`, `CF_PASSWORD`, `CF_ORG`, and `CF_SPACE` provided by secrets and inputs.
     - Executes `./scripts/pipeline/cloud-gov-login.sh` to perform the login.
     - Prints the targeted space: `echo "Targeting space: ${CF_SPACE}"`.
     - Sets the target using `cf target -s "${CF_SPACE}"`.
   - **Run Tome**:
     - Uses environment variables `PROJECT` and `CF_SPACE` to run a script `./scripts/pipeline/pipeline_wrapper.sh` with the `upkeep` parameter.
     - This script triggers the actual process to generate the static site.

#### Troubleshooting

- **Check Cloudfoundry CLI Installation**: 
  - Ensure that the output of `./scripts/pipeline/deb-cf-install.sh` does not show any errors. If there are issues, try running the script manually in a similar environment.
- **Verify Environment Variables**: 
  - Check if the necessary environment variables (`CF_USER`, `CF_PASSWORD`, `CF_ORG`, `PROJECT`, `CF_SPACE`) are correctly set as part of the secrets and inputs.
  - Incorrect or missing environment variables can cause login failures.
- **Login Issues**: 
  - If the `Cloud.gov login` step fails, carefully review the `source ./scripts/pipeline/cloud-gov-login.sh` command output for any authentication errors.
  - Ensure that the provided credentials are correct and have the necessary permissions for the specified `CF_SPACE`.
- **Job Condition Evaluation**: 
  - If the job does not run, inspect the `if: contains(vars.GENERATE_STATIC_SITE_ON_CRON_SPACES, inputs.CF_SPACE)` condition.
  - Ensure that the `CF_SPACE` input is correctly set and is part of the `GENERATE_STATIC_SITE_ON_CRON_SPACES` variable.
