### Runbook for `tf-bastion`

#### Introduction

This runbook is for operating the Terraform bastion. The code provided is a set of scripts designed to automate the deployment of a Terraform with HCL code, saving the state to a Postgres backend. The components include `apt.yml`, a YAML file for defining package repositories and keys; `exports.sh`, a Bash script to export environment variables; and a series of variable assignments and commands within a file possibly named `start.sh`.

#### Technical Breakdown

##### Configuration of Repositories and Keys (apt.yml)

According to the documents, the `apt.yml` file contains definitions for the PostgreSQL apt repository and public key. This file is used to ensure that the package manager is configured to pull the PostgreSQL client package from the correct and verified source.

- **Public Keys**: The repository key from the PostgreSQL website is added to ensure package integrity and authenticity.
  ```yaml
  keys:
    - https://www.postgresql.org/media/keys/ACCC4CF8.asc
  ```

- **Repositories**: The repository for the PostgreSQL client is specified as `deb https://apt.postgresql.org/pub/repos/apt jammy-pgdg main`. The `priority` field sets a high priority for these packages.
  ```yaml
  repos:
    - name: deb https://apt.postgresql.org/pub/repos/apt jammy-pgdg main
      priority: 999
  packages:
    - curl
    - gettext
    - git
    - postgresql-client-16
    - wget
  ```

##### Environment Variable Configuration (exports.sh)

The `exports.sh` script is a Bash script that extracts environment variables related to the PostgreSQL service from an environment variable named `VCAP_SERVICES`. This variable is typically set in cloud environments like Cloud Foundry. The script extracts `uri`, `db_name`, `host`, `password`, `port`, and `username` into bash environment variables for PostgreSQL connections.  Terraform, by default, will check these enviromental variables to use.

- **Extracting Database Connection Variables**:
  ```bash
  PGCONNSTR=$(echo "${VCAP_SERVICES}" | jq '."aws-rds"[].credentials.uri')
  PGDATABASE=$(echo "${VCAP_SERVICES}" | jq '."aws-rds"[].credentials.db_name')
  PGHOST=$(echo "${VCAP_SERVICES}" | jq '."aws-rds"[].credentials.host')
  PGPASSWORD=$(echo "${VCAP_SERVICES}" | jq '."aws-rds"[].credentials.password')
  PGPORT=$(echo "${VCAP_SERVICES}" | jq '."aws-rds"[].credentials.port')
  PGUSER=$(echo "${VCAP_SERVICES}" | jq '."aws-rds"[].credentials.username')
  ```

- **Exporting Variables**: The variables are then exported to `exports.sh` file.
  ```bash
  echo "export PATH=${PATH}:${home}/deps/0/bin" | tee "${home}/exports.sh"
  echo "alias terraform=tofu" | tee -a "${home}/exports.sh"
  echo "alias tf=tofu" | tee -a "${home}/exports.sh"
  echo "export PG_CONN_STR=${PG_CONN_STR}" | tee -a "${home}/exports.sh"
  echo "export PGDATABASE=${PGDATABASE}" | tee -a "${home}/exports.sh"
  echo "export PGHOST=${PGHOST}" | tee -a "${home}/exports.sh"
  echo "export PGPASSWORD=${PGPASSWORD}" | tee -a "${home}/exports.sh"
  echo "export PGPORT=${PGPORT}" | tee -a "${home}/exports.sh"
  echo "export PGUSER=${PGUSER}" | tee -a "${home}/exports.sh"
  echo "source exports.sh" | tee -a "${home}/.bashrc"
  ```

##### Installation and Configuration (start.sh)

The `start.sh` file provides the command sequence for downloading and installing OpenTofu, a fork of Terraform. The script specifies the version `OPENTOFU_VERSION` and uses `wget` to download a Debian package from GitHub, which is then installed using `dpkg-deb`. `OPENTOFU_VERSION` is set by environment variable in `terraform/bootstrap/locals.tf`.

- **Download and Installation of OpenTofu**:
  ```bash
  wget -q "https://github.com/opentofu/opentofu/releases/download/v${OPENTOFU_VERSION}/tofu_${OPENTOFU_VERSION}_amd64.deb"
  dpkg-deb -R "tofu_${OPENTOFU_VERSION}_amd64.deb" ${home}/deps/0/apt/
  ```

- **Linking Binaries**: The script manages binary links, ensuring that the file `tofu` in `~/deps/0/apt/usr/bin/` is linked to `~/deps/0/bin/tofu`.
  ```bash
  ln -s "${home}/deps/0/apt/usr/bin/tofu" "${home}/deps/0/bin/tofu"
  ```

- **Exporting Variables and Troubleshooting**: The `start.sh` script also sets environment variables for PostgreSQL connections, similar to `exports.sh`. The script includes a `while` loop at the end that essentially keeps the process running indefinitely.
  ```bash
  echo "Bastion ready!"
  while : ; do sleep 500 ; done
  ```

#### Troubleshooting

##### Possible Issues and Solutions

- **Key and Repository Configuration Errors**: Ensure the repository key is correctly added and that the repository path is valid. If there are issues with package queries, verify the `apt.yml` configuration.

- **Environment Variable Extraction Issues**: If variables are not being extracted correctly, verify the structure of the `VCAP_SERVICES` variable and the jq query syntax.

- **OpenTofu Download and Installation Issues**: Check network accessibility to GitHub. Make sure the `OPENTOFU_VERSION` variable has a valid value and that the Debian package exists and can be downloaded for that version.

- **Binary Link Errors**: If there are issues with the PostgreSQL binaries, check the existence and correct symlink establishment for binary files in the `/home/vcap/deps/0/bin/` directory.

- **Process Monitoring**: If the script fails to execute or the process does not start as expected, add verbose logging or increase the `sleep` interval to perform checks before assuming the process is stuck.
