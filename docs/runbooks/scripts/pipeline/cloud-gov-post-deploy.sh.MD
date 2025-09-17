### Runbook for `cloud-gov-post-deploy.sh`

#### Introduction

This script, `cloud-gov-post-deploy.sh`, is designed to handle the post-deployment steps for a Drupal application running on Cloud.gov. It waits for the app to become active, manages SSH access selectively based on the deployment space, and initiates the necessary update or installation processes. The script is written in bash and uses several Cloud.gov specific commands to interact with the environment.

#### Technical Breakdown

The script begins with setting bash to an error-prone mode using `set -e`. This ensures that the script will exit immediately if any command exits with a non-zero status.

  - **Deployment App Status Check:**
The script waits until the Drupal application is running in the environment before proceeding. It continuously checks the application status with the command `cf app "${PROJECT}-drupal-${CF_SPACE}" | grep running` until the application reports as running. This step is crucial for ensuring that the subsequent steps will not fail due to an unresponsive application.

  - **Enable SSH Access in Prod:**
For the production space (where `CF_SPACE` is "prod"), the script enables SSH access on the Drupal app with the command `cf enable-ssh "${PROJECT}-drupal-${CF_SPACE}"` and then performs a rolling restart of the app with `cf restart --strategy rolling "${PROJECT}-drupal-${CF_SPACE}"`. After this change, the script waits again for the Drupal app to become running, ensuring the new SSH status is recognized.

  - **Installation or Update Decision Logic:**
The script sets a default action as "update" for the Drupal environment with `DRUPAL_UPDATE_OR_INSTALL="update"`. It then checks if the current space matches any predefined spaces for installation (`INSTALL_DRUPAL_SPACES`). If a match is found, the action is changed to "install". 

  - **Post Deploy Steps Execution:**
The script runs the post-deployment steps by SSH-ing into the application with the command `cf ssh "${PROJECT}-drupal-${CF_SPACE}"`. It executes a script with a specific PATH environment and passes the action (either "update" or "install") to it. The output reflects the completion status as "Successfully completed post deploy!" or "Failed to complete post deploy!".

  - **SSH Access Cleanup:**
If the current environment is a production space, the SSH access is disabled after the post-deploy steps with the command `cf disable-ssh "${PROJECT}-drupal-${CF_SPACE}"`.

**Troubleshooting:**
- **Issue 1: App doesn't go to Running state**
  - *Symptom:* The script gets stuck in the "until" loop waiting for the app to be running.
  - *Solution:* Check the logs of the application and the Cloud.gov environment to find out why the application is not transitioning to the running state. Ensure there are no errors preventing the app from starting.

- **Issue 2: SSH Not Enabled Correctly**
  - *Symptom:* SSH commands fail in prod environment.
  - *Solution:* Verify that SSH is enabled correctly for the prod environment. Use `cf ssh "${PROJECT}-drupal-${CF_SPACE}"` manually outside the script to ensure that SSH functionality works as expected.

- **Issue 3: Incorrect Update/Install decision**
  - *Symptom:* The Drupal application does not update/install as expected.
  - *Solution:* Review the value of `$INSTALL_DRUPAL_SPACES` and the comparison logic in the script to ensure that the decision logic correctly identifies whether the action should be install or update.

