### Runbook for `gov-cloud-scp-file.sh`

#### **Introduction**

This runbook provides an overview and detailed instructions for executing the `gov-cloud-scp-file.sh` script designed to upload files or folders to a Cloud.gov application. The script relies on SSH configuration and access credentials to securely establish a connection and transfer data.

#### **Technical Breakdown**

The script `cloud-gov-scp-file.sh`, accepts three arguments:
1. `APP_NAME`: The name of the Cloud.gov application.
2. `LOCAL`: The local path to the file or folder to be uploaded.
3. `REMOTE`: The remote path where files will be placed in the Cloud.gov application.

The script begins by using the `cf app` command to retrieve the application's GUID (globally unique identifier). This GUID is used to construct the SSH user name. Subsequently, an SSH configuration file (`/tmp/ssh_config`) is created to specify the connection settings, including the hostname and port. The password is fetched using the `cf ssh-code` command and saved to `/tmp/ssh_password`.

The script then checks if the `LOCAL` path is a directory. If it is, the script uploads the entire directory with the `-r` option. Otherwise, it uploads the single file. In both cases, the data is transferred to the remote path specified in `REMOTE`.

##### **Script Structure and Functionality**

- **Argument Handling:**
  The script receives three command-line arguments, which are assigned to the variables `APP_NAME`, `LOCAL`, and `REMOTE`. These variables facilitate the rest of the script logic.

- **Authentication and Connection:**
  - The `APP_GUID` variable stores the GUID of the specified `APP_NAME`.
  - The SSH configuration file is generated within `/tmp` and sets the SSH connection parameters:
    - Hostname: `ssh.fr.cloud.gov`
    - Port: `2222`
    - User: `cf:GUID/0`, where `GUID` is derived from the application.
    - `StrictHostKeyChecking` is set to `no` to avoid interaction when verifying host keys.
  - The SSH password is stored in `/tmp/ssh_password` by executing the `cf ssh-code` command.

- **File/Directory Upload:**
  - If `LOCAL` is a directory, the `-r` option is used to recursively upload all files from the directory.
  - If `LOCAL` is a file, it is transferred as a single object.

- **Completion Notification:**
  Upon successful upload, the script prints "Upload complete."

##### **Troubleshooting**

- **Access Issues (SCP, SSH):**
  - Ensure that the application name (`APP_NAME`) is correctly specified.
  - Verify the existence of the local folder or file (`LOCAL`).
  - Confirm that the remote path (`REMOTE`) is writable.
  - Check SSH configuration and verify that no typos or incorrect settings are present.
  - Make sure that you have the necessary permissions for SCP and SSH operations.

- **Script Execution Errors:**
  - Check that the bash script, `cloud-gov-scp-file.sh`, has execution permissions. Use `chmod +x cloud-gov-scp-file.sh` to enable it if needed.
  - If the script fails, examine the output for error messages. Ensure that the Cloud Foundry CLI (`cf`) commands execute correctly.
  - Verify that the `${ssh_config}` and `${ssh_passwd}` files are correctly generated and accessible.

- **Host Key Verification Issues:**
  - If host key verification is enabled in your SSH configuration, it may prompt you for confirmation. This can be controlled by setting `StrictHostKeyChecking` explicitly if necessary (Note: current script already sets this to no).
