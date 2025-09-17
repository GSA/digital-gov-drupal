### Runbook for `database-backup.yml`

#### Introduction

This is the runbook for the GitHub Action workflow script `database-backup.yml`. The workflow is designed to perform a nightly database backup for a Drupal application hosted on Cloud.gov. The process includes starting a bastion host, performing the database backup, and then stopping the bastion host. The workflow also requires specific secrets and variables to configure the environment settings and to execute the necessary actions.

#### Technical Breakdown

1. **Workflow Triggers and Required Secrets:**
   The workflow is triggered daily at midnight (`cron: "0 0 * * *"`). Required secrets include:
   - `CF_USER`
   - `CF_PASSWORD`
   - `CF_ORG`
   - `PROJECT`
   - `DATABASE_BACKUP_BASTION_NAME`

2. **Start Bastion:**
   - If the GitHub ref is protected, initiate the bastion by setting up necessary environment variables and executing the Cloud.gov login script. This includes starting up the bastion server using the `cf start` command.
   - Environment variables for the bastion are set to facilitate the respective process according to the specific branch (`develop`, `main`, `stage`).

3. **Backup Database:**
   - The workflow waits for the bastion to start before proceeding with the backup operation.
   - This step includes environment configurations and the execution of the backup process.
   - The `export TIMESTAMP` variable captures the UTC time, which would be used for naming the backup files.
   - Finally, the backup operation is conducted using the necessary shell script.

4. **Stop Bastion:**
   - After the backup operation, the bastion is stopped. Similar to starting, necessary environment variables are configured to stop the server appropriately using the `cf stop` command.

#### Troubleshooting

1. **Bastion Start Failure:**
   - Verify if the required secrets are correctly set and that the `cf start` command receives the correct parameters.
   - If the start command fails, manually execute it with the relevant environment variables to diagnose the issue.

2. **Database Backup Failure:**
   - Ensure that the timestamp is properly captured and check if the relevant backup scripts (`database-backup.sh`) have the necessary permissions and are accessible.
   - If the error relates to permissions, update them accordingly. If the scripts are missing or broken, repair or reinstall them.

3. **Bastion Stop Failure:**
   - Confirm that the `cf stop` command is receiving the correct variables and parameter values.
   - Try the command manually to ensure that the bastion is properly shut down and the required variables are correctly set.
