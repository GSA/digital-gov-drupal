### Runbook for `database-backup.sh`

#### Introduction
This runbook provides an overview and technical documentation of the `database-backup.sh` script, designed to automate the backup process for MySQL databases. The script performs a number of actions, including setting up and shutting down SSH tunnels, extracting database credentials, creating backups, and uploading them to an S3 bucket. This guide will outline the steps involved in the script and provide relevant troubleshooting suggestions.

#### Technical Breakdown

The script `database-backup.sh` comprises several key functions and processes:

1. **Killing Existing Connections**
   - The `kill_pids` function is used to terminate any ongoing SSH tunnels established to the MySQL database.

2. **Waiting for SSH Tunnel**
   - The `wait_for_tunnel` function monitors the progress of an SSH tunnel initiation, primarily checking for the specific message `"Press Control-C to stop."` in the `backup.txt` file.

3. **Connecting to MySQL**
   - The script establishes a tunnel to the project's MySQL service through `cf connect-to-service`. This tunnel creation is a prerequisite for pulling the database backup.

4. **Extracting Credentials and Creating Backup File**
   - Once the tunnel is established and the database endpoint details are available, the script extracts the necessary credentials and writes them to a MySQL configuration file (`~/.mysql/mysqldump.cnf`). The script also skips certain tables known to be non-data intensive.

5. **Dumping Database Structure and Content**
   - There are two stages of data dumping. In the first stage, the structure of the database is dumped into a file (`backup_${CF_SPACE}.sql`). In the following stage, the database content is dumped into the same file, excluding tables specified in the `excluded_tables` array.

6. **Cleaning Up and Compressing**
   - The script cleans up temporary files and backgrounded tunnels, moves and compresses the backup file (`backup_${CF_SPACE}.sql`) into a `.sql.gz` file.

7. **Setting S3 Credentials and Uploading Backup**
   - S3 authentication credentials are extracted from a bastion host and exported to environment variables. The backup file is subsequently uploaded to an S3 bucket using the AWS CLI with timestamps embedded in the backup filename.

#### Troubleshooting
- **Understanding Error Messages**: Errors like missing SSH tunnel message or SQL dump failures could indicate issues with SSH configurations or access denial to the database.
  - **Potential Solutions**: Verify the SSH tunnel configuration, ensure MySQL user privileges, and check the `backup.txt` file for any unusual messages.
  
- **S3 Upload Errors**: Errors during the S3 upload process can occur due to incorrect cloud credentials setup.
  - **Potential Solutions**: Check the cloud credentials and revalidate the connection to the S3 bucket using the AWS CLI.

- **Network Timeouts**: A script hang during the `wait_for_tunnel` function might be caused by network issues or excessive wait times.
  - **Potential Solutions**: Adjust timeout behavior if applicable or check network conditions impacting the SSH connection.
