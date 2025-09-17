### Runbook for `database-restore.yml`

#### Introduction

This runbook provides a guide for executing the database restoration process using the provided code, written in a GitHub Actions workflow syntax. The primary focus of the code is to automate the restoration of a database either from a standard process or an overridden S3 path specified by the user through a workflow dispatch.

#### Technical Breakdown

The workflow defined is structured into three main jobs: `start-bastion`, `restore-database`, `stop-bastion`, and preliminary steps within each job to set up environments, dependencies, and authentication credentials.

1. **Start Bastion**
   - **Checkout**: The job starts by checking out the repository code using `actions/checkout@v4`.
   - **Set env.BRANCH**: The job sets the `BRANCH` variable, which is used to determine the Cloud Foundry space (`CF_SPACE`) depending on the branch from which the workflow is run.
   - **Install Basic Dependencies**: Basic dependencies are installed to ensure the necessary tools are available for the workflow.
   - **Install Cloudfoundry CLI**: The Cloudfoundry command-line interface is installed for the job.
   - **Cloud.gov Login**: Authentication to Cloud.gov is handled through an environment variable-based script, ensuring all required actions are performed within a secure context.
   - **Start Bastion**: A bastion is started by the job, referencing a Cloud Foundry application instance identified by `PROJECT`, `DATABASE_BACKUP_BASTION_NAME`, and `CF_SPACE`. The job waits for the bastion to be active before proceeding.

2. **Restore Database**
   - **Checkout**: Similar to the `start-bastion` job, this job first checks out the repository code to ensure access to necessary scripts and configurations.
   - **Set env.BRANCH**: This step also sets the `BRANCH` and `CF_SPACE` environment variables, crucial for determining the context in which the restoration will occur.
   - **Install Basic Dependencies and AWS CLI**: The job ensures the presence of basic dependencies and the AWS CLI for handling S3 interactions.
   - **Install MySQL Client**: The MySQL client is installed for performing database operations.
   - **Cloud.gov Login**: The job performs a Cloud.gov login, an initialization step for secure database actions.
   - **Restore Database**: This step restores the database either from a default location or an overridden path, specified by the `database_file_override` input if provided. It retrieves the backup file from S3, restores the database via a script, and performs a post-deployment check.

      A valid string value for `database_file_override` can be retrieved with:
      ```bash
      cf target -s <space>
      source ./scripts/cloud-gov-s3-creds.sh
      aws s3 ls s3://${AWS_BUCKET} --recursive | awk '{print $NF}'
      ```

      Copy the filename, with the full path and place it into the pipeline's `database_file_overrride` field.

3. **Stop Bastion**
   - **Checkout**: The repository code is checked out to ensure consistency.
   - **Set env.BRANCH**: The environment variables needed for identifying the context are set.
   - **Install Basic Dependencies and Cloudfoundry CLI**: The job sets up the dependencies and initializes the Cloudfoundry CLI.
   - **Cloud.gov Login**: The job authenticates to Cloud.gov.
   - **Stop Bastion**: The bastion instance that was started previously is stopped, minimizing resource utilization and ensuring all actions are encapsulated within a correct security context.

#### Troubleshooting

- **Authentication Issues**: If faced with issues during the authentication step (`Cloud.gov login`), ensure that the secrets (`CF_USER`, `CF_PASSWORD`, `CF_ORG`, `PROJECT`) are correctly configured in the repository’s Secrets setting.
  
- **Dependency Installation Failures**: If the basic dependencies or specific application dependencies like the AWS CLI or MySQL client fail to install, review the respective installation scripts (`deb-basic-deps.sh`, `awscli-install.sh`, `deb-mysql-client-install.sh`, `deb-cf-install.sh`) for any known bugs or modifications that might be required for the current environment.
  
- **Database Restore Failures**: Any errors related to restoring the database may be due to an incorrect path specified or permissions issues while accessing the path on S3. Verify that the path specified by `database_file_override` input is correct and that you have the necessary permissions to access the file.

- **Bastion Start/Stop Failures**: Ensure that the Cloud Foundry application instance specified in `DATABASE_BACKUP_BASTION_NAME` is correctly defined and the Cloud Foundry command-line interface has the necessary permissions to start/stop the instance. Check the output of these commands for any specific error messages that can guide you towards the resolution.
