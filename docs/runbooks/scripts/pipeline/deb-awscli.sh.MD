### Runbook for `deb-awscli.sh`

#### Introduction

This runbook provides detailed information on a script named `deb-awscli.sh`, which is designed to automate the installation of the AWS CLI on Linux systems. The script is crafted to handle installations both for users with sudo privileges and for root users, ensuring a seamless deployment process regardless of the user role.

#### Technical Breakdown

The script `deb-awscli.sh` initiates by checking the user identity with the command `whoami`. This conditional approach allows the script to handle different user permissions, as described:
- **For non-root users**: The script performs the AWS CLI installation using `curl` to download a specific versioned `.zip` file, `awscliv2.zip`. The `unzip` command extracts the file, and `sudo` is utilized to execute the `aws/install` script with specified parameters for installation directories.
- **For root users**: The installation process is similar, except for the use of `sudo`. The `curl` and `unzip` commands still download and extract the file, but the installation script (`aws/install`) is executed directly for root users.

The installation command includes parameters that detail the bin directory (`/usr/local/bin`) and install directory (`/usr/local/aws-cli`), ensuring the binary is placed in a standard location. Redirection (`>/dev/null 2>&1`) is used to suppress the output of the installation process, streamlining the user experience.

#### Troubleshooting

When using the provided script, several issues may arise that can hinder the installation progress. Here are some common troubleshooting steps based on the script's process:

- **Check User Context**: Ensure the user running the script has the correct privileges. For non-root users, confirm sudo access is available to perform the installation.

- **Network Issues**: If the file fails to download, verify the system's internet connection and check for any network restrictions, such as firewalls or proxies.

- **File permissions**: If the installation script fails, examine the permissions on the `awscliv2.zip` and the installation directories to ensure they are writeable. You may need to adjust these permissions (using `chmod`) to complete the installation.

- **Download Path**: Ensure the URL used in the `curl` command is correct. Adjust if you find a different or updated link for the AWS CLI installer package.

- **Unzip and Install Failures**: Should the `unzip` or `aws/install` commands fail, consider manually downloading, unzipping, and executing the installation steps to diagnose and resolve the issue.
