### Runbook for `bootstrap.sh`

#### Overview

This runbook provides detailed instructions for executing the `bootstrap.sh` Bash script, aimed at setting up and configuring an application environment for running a PHP application. The script handles the following tasks:
- Exporting necessary environment variables.
- Configuring New Relic for monitoring.
- Setting up directories and permissions.
- Updating the environment's `PATH` variable.
- Installing `awscli`.
- Executing post-deployment steps (conditional).

#### Prerequisites

Before running the `bootstrap.sh` script, ensure the following requirements are met:
- The environment variable `VCAP_SERVICES` is set and contains the required service information.
- The environment variable `VCAP_APPLICATION` is set to provide application context.
- The necessary file system permissions are in place for the script's directories and files.
- The `jq` command-line JSON processor is installed and available in `PATH`.

#### Technical Breakdown

1. **Prepare the Environment**

    Ensure that the `VCAP_SERVICES` and `VCAP_APPLICATION` environment variables are set. These are provided by Cloud Foundry, assuming the application is bound to the correct services.

2. **Execute the Bootstrap Script**

    This script is automatically launched during the startup process of the buildpack. It is called from `.bp-config/options.json`, set in the `ADDITIONAL_PREPROCESS_CMDS` array.
    
    The script will automatically:
    - Set up the `home` and `app_path` variables.
    - Validate the existence of `VCAP_SERVICES`.
    - Extract the application name and New Relic license key from `VCAP_SERVICES` and `VCAP_APPLICATION`.
    - Find the New Relic ini and so files.
    - Create symbolic links for these files to the correct directories.
    - Update the New Relic ini configuration file with the appropriate settings.
    - Create necessary directories and set permissions.
    - Update the `PATH` variable in the `.bashrc` file.
    - Install `awscli` silently.
    
3. **Verify Script Execution**
    
    - Ensure that the required directories such as `${HOME}/private`, `${HOME}/web/sites/default/files`, and `./container_start_timestamp` are correctly created and have the right permissions.
    - Check the `.bashrc` file to ensure that the `PATH` was correctly updated and necessary aliases (e.g., `nano`) are present.
    - Confirm that `awscli` is installed successfully and accessible via `PATH`.

#### Troubleshooting

- **Check Environment Variables**: Verify that `VCAP_SERVICES` and `VCAP_APPLICATION` contain the necessary details and are correctly formatted.
  
- **Directory Permissions**: Ensure that the script has sufficient permissions to create directories and modify files in the specified paths.
  
- **JSON Parsing**: Check if `jq` is installed and accessible. Verify that the JSON data in `VCAP_SERVICES` and `VCAP_APPLICATION` is correctly formatted.
  
- **Script Errors**: If the script fails, review the error messages and ensure that all necessary dependencies and services are correctly configured.

#### Best Practices

- **Testing Environment**: Testing the script in a controlled and isolated environment before moving to the production environment can prevent unexpected issues.
- **Logging**: Consider adding logging to the script for better debugging and monitoring of the setup process.
- **Environment Consistency**: Ensure consistency across different deployment environments to avoid configuration drift.
