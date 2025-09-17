### Runbook for `cloud-gov-remote-command.sh`

#### Introduction
This runbook provides guidance on using the `cloud-gov-remote-command.sh` script for executing remote commands on applications hosted on Cloud.gov. The script takes three key inputs: the name of the application, the command to be executed, and a flag to control whether the command's output is shown. It handles the SSH configuration and execution process to ensure secure communication with the application's environment.

#### Technical Breakdown

##### **Script Structure and Functionality**

The `cloud-gov-remote-command.sh` script is a Bash script designed to execute remote commands on Cloud.gov applications. The script accepts three arguments:
1. The name of the application (`APP_NAME`).
2. The command to be executed on the application (`command`).
3. A flag to toggle output display (`show_output`).

Upon execution, the script performs a series of steps:

1. **Check Required Inputs:**
   - The script first checks to ensure both `APP_NAME` and `command` are provided. If either of these variables is missing, an error message is displayed: "Command error! Valid format: ${0} <application_name> <command>".

2. **Retrieve Application GUID:**
   - The script retrieves the application's GUID using the `cf app` command and stores it in the `APP_GUID` variable.

3. **Set Up SSH Configuration:**
   - The SSH configuration file (`ssh_config`) is created with the necessary details for connecting to the application on Cloud.gov. This includes setting the `User` to `cf:${APP_GUID}/0` and disabling strict host key checking.
   - The SSH password is generated using `cf ssh-code` and stored in the `ssh_passwd` file.

4. **SSH Command Execution:**
   - The script then uses `sshpass` to pass the password from the file and execute the SSH command with the configured settings. If the `show_output` flag is unset, the output of the command is suppressed. Otherwise, the output is displayed.

##### **Example Usage**
To execute the `ls -lah` command on an application named "my-app" and show the output, you would run:
```bash
./cloud-gov-remote-command.sh my-app "ls -lah" 1
```

##### **Environment Variables**
- The script sets up a `precommand` string that ensures the PATH is appropriately configured on the remote machine:
  ```bash
  precommand="touch ~/exports.sh && source ~/exports.sh && PATH=\$PATH:${bin_path}"
  ```

##### **Dependencies**
- The script requires the `cf` command line interface to be installed and authenticated on the local machine.
- It also relies on `sshpass` for password input during the SSH session.

#### Troubleshooting

**Common Issues and Solutions**

1. **SSH Code Retrieval Error:**
   - This error may occur if the `cf ssh-code` command fails to retrieve the necessary password. Ensure that the `cf` CLI is correctly installed and logged in with the required permissions.
   
   *Solution:*
   - Try logging out and logging back into the Cloud Foundry environment using `cf logout` and `cf login` to refresh authentication.

2. **SSH Connection Refused:**
   - When SSH connections are refused, there might be issues with the configuration.
   
   *Solution:*
   - Verify that the Cloud.gov application's environment allows SSH with `cf enable-ssh`.
   
3. **Command Execution Issues:**
   - If the remote command is not executed as expected, check the correctness of the command syntax and the application's running environment.
   
   *Solution:*
   - Manually SSH into the Cloud.gov application environment using `cf ssh` to test the command directly.
