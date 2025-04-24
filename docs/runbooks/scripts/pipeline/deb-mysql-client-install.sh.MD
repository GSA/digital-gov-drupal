### Runbook for `deb-mysql-client-install.sh`

### Introduction
The script`deb-mysql-client-install.sh` is a Bash script designed to install the `mysql-client-8.0` package on a Debian-based Linux distribution. It handles the installation process while accounting for user privileges, which enables it to run both as a non-root user and with elevated permissions when necessary.

### Technical Breakdown

The script checks whether the script is being run by the `root` user and adapts the installation commands accordingly:
```bash
if [ "$(whoami)" != "root" ]; then
  sudo apt-get update
  sudo apt-get install -y mysql-client-8.0
else
  apt-get update
  apt-get install -y mysql-client-8.0
fi
```

- **Non-root user**: For non-root users, the script uses `sudo` to execute the package manager updates and installation with elevated privileges.
- **Root user**: When running as root, the script executes the package manager without `sudo`.

#### Troubleshooting
- **Issue:** If the script fails with an error indicating a missing package, ensure `apt-get` can reach appropriate repositories.
    - **Resolution:** Check `/etc/apt/sources.list` and subsequent files in `/etc/apt/sources.list.d/` to verify the repositories are correctly defined.
- **Issue:** Command not found or missing dependency errors.
    - **Resolution:** Verify the base system software is up-to-date prior to running the script.
- **Issue:** Errors related to being unable to grant elevated permissions using `sudo`.
    - **Resolution:** Ensure the non-root user has the necessary `sudo` privileges. This can be checked and set using the `/etc/sudoers` file. Also, consider running the script as root if the user configuration cannot be changed.
- **Issue:** Installation fails due to network issues.
    - **Resolution:** Check the network connectivity and verify that the system can access the necessary repositories online.
