### Runbook for `database-backup-bastion`

#### Overview

This code is used to deploy the database backup bastion. It consists of a Bash script designed to manage database connections and environment configurations for both MySQL and PostgreSQL databases, as well as AWS S3 credentials. The script aims to extract relevant information from the `VCAP_SERVICES` environment variable, set the necessary environment variables, and create symbolic links for the PostgreSQL binaries to ensure proper execution.

The `apt.yml` file installs the packages for MySQL and Postgres via the apt buildpack.

#### Technical Breakdown

##### Setting Environment Variables

The script starts by identifying relevant database information from the `VCAP_SERVICES` environment variable and assigns it to variables for MySQL and PostgreSQL. The following snippets demonstrate how the script handles the variable assignments:

- **MySQL Database:**
```bash
MYSQL_CONN_STR=$(echo "${VCAP_SERVICES}" | jq '."aws-rds"[] | select(.plan | contains("mysql")) | .credentials.uri')
# Repeat the process for MYSQL_DATABASE, MYSQL_HOST, MYSQL_PASSWORD, MYSQL_PORT, and MYSQL_USER
```

- **PostgreSQL Database:**
```bash
PG_CONN_STR=$(echo "${VCAP_SERVICES}" | jq '."aws-rds"[] | select(.plan | contains("psql")) | .credentials.uri')
# Repeat the process for PGDATABASE, PGHOST, PGPASSWORD, PGPORT, and PGUSER
```

The script then checks if the connection strings for MySQL and PostgreSQL are set. If they are, the script writes the environment variables to `exports.sh`:

```bash
if [ -n "${MYSQL_CONN_STR}" ]; then
  {
    echo "export MYSQL_CONN_STR=${MYSQL_CONN_STR}"
    # Repeat for MYSQL_DATABASE, MYSQL_HOST, MYSQL_PASSWORD, MYSQL_PORT, and MYSQL_USER
  } >> "${home}/exports.sh"
fi

if [ -n "${PG_CONN_STR}" ]; then
  {
    echo "export PG_CONN_STR=${PG_CONN_STR}"
    # Repeat for PGDATABASE, PGHOST, PGPASSWORD, PGPORT, and PGUSER
  } >> "${home}/exports.sh"
fi
```

##### AWS S3 Credentials

The script also handles AWS S3 credentials:

- **AWS S3 Variable Extraction:**
```bash
AWS_ACCESS_KEY_ID=$(echo "${VCAP_SERVICES}" | jq '.s3[] | select(.name | contains("backup")) | .credentials.access_key_id')
# Repeat for AWS_SECRET_ACCESS_KEY, AWS_DEFAULT_REGION, AWS_BUCKET, AWS_ENDPOINT, and AWS_FIPS_ENDPOINT
```

- **Writing to `exports.sh`:**
```bash
if [ -n "${AWS_ACCESS_KEY_ID}" ]; then
  {
    echo "export AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID}"
    # Repeat for the other variables
  } >> "${home}/exports.sh"
fi
```

##### PostgreSQL Symbolic Link Fix

The script ensures that the PostgreSQL binaries are correctly linked in the `bin` directory:

```bash
symlinks=($(find /home/vcap/deps/0/bin | awk 'NR > 1 {print $NF}' | grep pg_) /home/vcap/deps/0/bin/psql)
psql_binaries=($(find /home/vcap/deps/0/apt/usr/lib/postgresql/*/bin | awk 'NR > 1 {print $NF}'))

for symlink in "${symlinks[@]}"; do
  for binary in "${psql_binaries[@]}"; do
    symlink_file=$(basename "${symlink}")
    binary_file=$(basename "${binary}")
    if [ "${symlink_file}" = "${binary_file}" ]; then
      rm "${symlink}"
      ln -s "${binary}" "${symlink}"
    fi
  done
done
```

##### File Management and Environment Variable Activation

Finally, the script appends an instruction to source `exports.sh` into the `.bashrc` file:

```bash
echo "source exports.sh" >> "${home}/.bashrc"
```

#### Troubleshooting:

The setup and usage of this script might encounter several issues. Here are troubleshooting steps for potential problems:

- **Missing Environment Variables:**
  - If the necessary environment variables within `VCAP_SERVICES` are missing or incorrectly formatted, the script will not successfully extract the required data. Verify the format and content of `VCAP_SERVICES` by using `echo ${VCAP_SERVICES}` and confirming the correctness of `jq` queries.

- **Incorrect Symbolic Link Creation:**
  - Should the symbolic links not be created correctly, this could interfere with the execution of PostgreSQL commands.
  - Manually verify the existence and correctness of the binary files and their corresponding links using `ls -l` in the `/home/vcap/deps/0/bin` and `/home/vcap/deps/0/apt/usr/lib/postgresql/*/bin` directories.

- **Script Execution Errors:**
  - Ensure that the script is executable. You can set it as executable with `chmod +x [filename]`.
  - Run the script with `bash [filename]` to check for any syntax or runtime errors.