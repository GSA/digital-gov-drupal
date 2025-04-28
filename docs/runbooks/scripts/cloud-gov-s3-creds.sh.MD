### Runbook for `cloud-gov-s3-creds.sh`

#### Introduction
The script `cloud-gov-s3-creds.sh` manages AWS S3 credentials for environments on Cloud.gov. It ensures that the necessary access keys and secret keys are correctly exported into the shell environment, allowing for seamless interaction with the S3 bucket. This script is useful for operations involving direct access to AWS S3 buckets on the Cloud.gov platform.

#### Technical Breakdown

1. **User Variable Initialization**
   - The script starts by retrieving the current user's name and processing it to ensure it contains only alphanumeric characters. This is important for creating a unique identifier for the user when interacting with Cloud.gov services.

   ```bash
   user=$(whoami | tr -dc '[:alnum:]\n\r' | tr '[:upper:]' '[:lower:]')
   ```

2. **Error Handling for Missing Bucket Name**
   - Before proceeding, the script validates if the `bucket_name` environment variable is correctly set. If not, it outputs an error message and instructs the user on how to properly export the `bucket_name`.

   ```bash
   if [ -z "${bucket_name}" ]; then
       echo -e "Error: No bucket name is set!\n"
       # Instructions and usage example
   fi
   ```

3. **Check for Active Cloud.gov User Session**
   - The script performs a check to see if there is a valid Cloud.gov session in place by verifying `cf orgs` output. The presence of "FAILED" in the output denotes an error state, causing the script to terminate silently if detected.

   ```bash
   if [ -n "$(cf orgs | grep FAILED)" ]; then
       return
   fi
   ```

4. **Credential Management**
   - The script then handles credential management for the specified S3 bucket. It deletes any previous service keys to ensure clean setup before creating new ones. This is performed with commands such as `cf delete-service-key` and `cf create-service-key`, which interact with the Cloud.gov API to manage access to S3 buckets.

   ```bash
   echo "Deleting old credentials..."
   service_key="${bucket_name}-${user}-key"
   cf delete-service-key "${bucket_name}" "${service_key}" -f

   ## Creating new credentials
   cf create-service-key "${bucket_name}" "${service_key}"
   s3_credentials=$(cf service-key "${bucket_name}" "${service_key}" | tail -n +2)
   ```

5. **Environment Variable Export**
   - After creating the service key, the script extracts the necessary credentials (access key, bucket name, region, and secret key) from the service key response and exports them as environment variables. Additionally, it creates a script file `current_creds.sh` that stores these values for future reference or automated use.

   ```bash
   aws_access_key=$(echo "${s3_credentials}" | jq -r '.credentials.access_key_id')
   aws_bucket_name=$(echo "${s3_credentials}" | jq -r '.credentials.bucket')
   aws_bucket_region=$(echo "${s3_credentials}" | jq -r '.credentials.region')
   aws_secret_key=$(echo "${s3_credentials}" | jq -r '.credentials.secret_access_key')

   declare AWS_ACCESS_KEY_ID
   export AWS_ACCESS_KEY_ID=${aws_access_key}

   # Likewise for other variables

   cat >~/current_creds.sh << EOT
   # Export commands
   EOT
   chmod +x ~/current_creds.sh
   ```

6. **Final Error Handling**
   - The script concludes by checking if the `AWS_ACCESS_KEY_ID` has been correctly exported. If not, a fail-safe message displays and the script exits with an error code.

   ```bash
   if [ -z "${AWS_ACCESS_KEY_ID}" ]; then
       echo -e "Error setting AWS credentials."
       # Additional error messages
       if [ -z "${CI}" ]; then
           return
       fi
       exit 1
   fi
   ```

#### Troubleshooting

1. **Missing Bucket Name**
   - **Symptom:** The script outputs an error message stating  that no bucket name is set.
   - **Solution:** Ensure that the `bucket_name` environment variable is correctly exported before running the script. Use `export bucket_name=<your-bucket-name>` in your environment before executing the script.
   
   ```bash
   export bucket_name=project-bucket-name-environment
   ```

2. **Inactive Cloud.gov Session**
   - **Symptom:** The script runs but fails silently if `cf orgs` returns "FAILED".
   - **Solution:** Ensure that you are properly logged in to Cloud.gov.
   ```bash
   cf login -a api.fr.cloud.gov --sso
   ```

3. **AWS Credentials Not Set**
   - **Symptom:** The script outputs an error message stating that AWS credentials are not set.
   - **Solution:** Verify that you are logged in to Cloud.gov with the correct user account and active session.

   ```bash
   cf target -s <space_name>
   ```

4. **Service Key Creation/Deletion Issues**
   - **Symptom:** Problems with generating or deleting service keys may occur due to permissions issues or Cloud.gov API problems.
   - **Solution:** Check your user permissions in Cloud.gov. Ensure that you have the necessary permissions to create and delete service keys. Additionally, check the API status on the Cloud.gov status page for any ongoing issues.

   ```bash
   cf orgs
   cf spaces
   ```

5. **jq Command Not Found**
   - **Symptom:** If you encounter an error such as `command not found: jq`, the script will fail.
   - **Solution:** Install `jq` on the system to parse JSON output. On Debian-based systems, use `sudo apt-get install jq`. On macOS, use `brew install jq`.

   ```bash
   sudo apt-get install jq
   ```

6. **Incorrect AWS Environment Variable Exports**
   - **Symptom:** If the AWS credentials are not correctly exported, subsequent commands will fail due to missing environment variables.
   - **Solution:** Ensure the script is reaching the export lines and there are no environment overrides causing issues. Verify the content of `current_creds.sh` and source it manually to test.

   ```bash
   source ~/current_creds.sh
   ```

7. **Access Forbidden or Permission Issues**
   - **Symptom:** If you encounter "access forbidden" errors when attempting to interact with the S3 bucket.
   - **Solution:** Double-check your IAM permissions on the AWS side. Ensure the service key generated has all necessary permissions to access the S3 bucket.

   ```bash
   cf service-key <your-service-key-name>
   ```

#### Additional Tips
- **Log Outputs:** During troubleshooting, it is helpful to run the script with increased verbosity by removing or modifying the `>/dev/null 2>&1` redirection to capture more information.
  
- **Test Each Step:** After making changes, test each step of the script in isolation to ensure functionality.
  
- **Consult Documentation:** Refer to the [Cloud.gov documentation](https://cloud.gov/) and [AWS documentation](https://aws.amazon.com/documentation/) for detailed information on specific services and permissions.
