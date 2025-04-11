### Runbook for `terraform-build-waf-plugin.sh`

#### Introduction
This runbook is for the `terraform-build-waf-plugin.sh` script, which involves building, moving, and deploying a Web Application Firewall (WAF) module for the Nginx web server. The script handles both the local building of the module and, via SSH commands to a remote server, ensures directory structures are in place and moves the built module to a bastion host for further deployment. At a high level, the script checks the presence of required version variables, builds the WAF module using a Makefile, and copies the resulting module to a specified path on the remote server.

#### Technical Breakdown

##### Variable Checks
The script begins with checks to ensure the presence of several environment variables, namely:
- `${new_nginx_version}`
- `${modsecurity_nginx_version}`
- `${ubuntu_version}`

If any of these variables are missing, the script will terminate and return an error message. This is an essential safeguard to ensure that all necessary version information is available before proceeding.

##### Directory Management
The sequence of commands handles navigation through the filesystem:

1. Save the current directory path to `CWD` and set the path to the WAF application as `APP_PATH`.
2. Move into the `.docker` subdirectory found within the `APP_PATH`.
3. With the working directory now inside the `.docker` subdirectory, the `make` command is executed to build the WAF module. This step depends on the presence of a `Makefile` within this directory to carry out the build process.
4. The script then returns to the original working directory saved in `CWD`.

##### Remote Commands and File Operations
Following the local build process, the script interacts with a remote bastion server (identified by `${TF_BASTION}`) to prepare for the deployment of the built module. This involves two main steps:

1. A remote command ensures that the necessary directory structure exists on the remote server by using a script (`cloud-gov-remote-command.sh`) to send the `mkdir` command to create specified directories.
2. Once the directories are in place, the script transfers the generated module to the remote server using another script (`cloud-gov-scp-file.sh`), which performs an `scp` (secure copy) operation, copying files from the local `.docker` path to the remote destination. The notion is to move the module into a directory on the server set by `${REPO_NAME}/${APP_PATH}/`.

##### Troubleshooting

###### Variable Errors
If the script reports errors related to unset environment variables, verify that the necessary variables are provided and correctly referenced in the setting scope. A common reason for this to occur is that the environment is not correctly configured or the variables were not set before executing the script.

###### Directory and File Operations
Errors during directory change operations (for example, if `cd` commands fail) generally point to misconfigured or missing paths. Ensure the `APP_PATH` and `CWD` are accurate and that the filesystem directories are as expected. Issues with `make`, such as when the build process aborts, can be due to an incorrect `Makefile` or missing build dependencies.

For remote command execution and file transfer operations, check the connectivity and permissions settings on the remote server (`${TF_BASTION}`). Misconfigurations, network failures, or insufficient permissions can cause these operations to fail.

Should any of these steps fail, the best approach is to manually reproduce the commands interactively within the shell to trace back the issue and supply appropriate feedback to the script's execution.
