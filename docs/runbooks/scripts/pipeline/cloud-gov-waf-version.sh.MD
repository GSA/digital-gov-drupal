### Runbook for `cloud-gov-waf-version.sh`

#### Overview

The script `cloud-gov-waf-version.sh` is a bash script designed to check for new versions of an nginx buildpack and update the environment variables accordingly. It also initializes the necessary libraries and checks if there are new versions available. The script runs a series of commands to determine the current and new versions of the nginx buildpack, extracts the relevant nginx version from the GitHub releases page, and makes decisions based on whether an update is necessary.

#### Technical Breakdown

##### Initialization and Version Comparison

The script starts by defining a `version` function that converts version numbers (e.g., `1.2.3.4`) into a sortable numeric format. This function is used to compare versions later in the script.

```bash
function version {
  echo "$@" | awk -F. '{ printf("%d%03d%03d%03d\n", $1,$2,$3,$4); }';
}
```

The script then checks if `pup` (a utility for processing HTML with jQuery-like selectors in shell scripts) is installed. If it is not installed, it installs `pup` based on whether the user has root access or not.

```bash
if [ -z "$(which pup)" ] ; then
  if [ "$(whoami)" != "root" ] ; then
    sudo wget -q --show-progress https://github.com/ericchiang/pup/releases/download/v0.4.0/pup_v0.4.0_linux_amd64.zip
    sudo unzip pup_v0.4.0_linux_amd64.zip -d /usr/local/bin
  else
    wget -q --show-progress https://github.com/ERICCHIANG/pup/releases/download/v0.4.0/pup_v0.4.0_linux_amd64.zip
    unzip pup_v0.4.0_linux_amd64.zip -d /usr/local/bin
  fi
fi
```

##### Determine Current and New Buildpack Versions

The script retrieves the current version of the nginx buildpack in use from a Cloud Foundry application:

```bash
declare CURRENT_BP_VERSION
CURRENT_BP_VERSION=$(cf app "${PROJECT}-waf-${BRANCH}" | grep nginx_buildpack | xargs | awk '{print $2}')
```

It also fetches the newest available version of the nginx buildpack:

```bash
declare NEW_BP_VERSION
NEW_BP_VERSION=$(cf buildpacks | grep nginx | grep cflinuxfs4 | awk '{print $NF}' | grep -Eo '[0-9]\.[0-9]?(.[0-9]+)')
```

Both versions are then converted to the sortable version numbers using the `version` function:

```bash
new_bp_version=$(version "${NEW_BP_VERSION}")
current_bp_version=$(version "${CURRENT_BP_VERSION}")
```

##### Extract Nginx Versions

The script retrieves the current and new versions of nginx from the GitHub release pages for the buildpack versions:

```bash
curl -Ls "https://github.com/cloudfoundry/nginx-buildpack/releases/tag/v${CURRENT_BP_VERSION}" > /tmp/current_bp_version
declare current_nginx_version
current_nginx_version=$(cat /tmp/current_bp_version | pup 'table json{}' | jq -r '.[].children[].children[] | select(.children[].text == "nginx") | select(.children[].text == "cflinuxfs4") | .children[].text' | tr '\n' ' ' | sed -E 's/cflinuxfs4 /cflinuxfs4\n/g' | sort -r | head -n 1 | awk '{print $2}')
```

and for the new version:

```bash
curl -Ls "https://github.com/cloudfoundry/nginx-buildpack/releases/tag/v${NEW_BP_VERSION}" > /tmp/new_nginx_version 
declare default_nginx_binary_version
default_nginx_binary_version=$(cat /tmp/new_nginx_version | pup 'table json{}' | jq -r '.[].children[].children[] | select(.children[].text == "nginx") | select(.children[].text | contains(".x")) | .children[].text' | grep -v nginx | sed 's/.\{1\}$//')

declare new_nginx_version
new_nginx_version=$(cat /tmp/new_nginx_version | pup 'table json{}' | jq -r ".[].children[].children[] | select(.children[].text == \"nginx\") | select(.children[].text == \"cflinuxfs4\") | select(.children[].text | contains(\"${default_nginx_binary_version}\")) | .children[].text" | tr '\n' ' ' | sed -E 's/cflinuxfs4 /cflinuxfs4\n/g' | sort -r | head -n 1 | awk '{print $2}')
```

##### Update Decision and Output

The script then compares the new and current versions of the buildpack and takes action accordingly:

```bash
if [ "${new_bp_version}" -ne "${current_bp_version}" ]; then
  echo "New version of buildpack found!"
  echo "update=true" | tee -a "${GITHUB_OUTPUT}"
  export update=true
else
  echo "Running latest version of the buildpack!"
fi
```

Outputs the updated variables to the `${GITHUB_OUTPUT}`:

```bash
echo "new_nginx_version=${new_nginx_version}" | tee -a "${GITHUB_OUTPUT}"
echo "current_nginx_version=${current_nginx_version}" | tee -a "${GITHUB_OUTPUT}"
echo "current_bp_version=${CURRENT_BP_VERSION}" | tee -a "${GITHUB_OUTPUT}"
echo "new_bp_version=${NEW_BP_VERSION}" | tee -a "${GITHUB_OUTPUT}"
```

And exports the environment variables for later use:

```bash
export new_nginx_version=${new_nginx_version}
export current_nginx_version=${current_nginx_version}
export current_bp_version=${CURRENT_BP_VERSION}
export new_bp_version=${NEW_BP_VERSION}
```

#### Troubleshooting

- **Error Installing `pup`:** If `pup` cannot be installed, check if the user has required permissions, or if there are network issues with reaching the download URL.
- **Incorrect Version Parsing:** If the parse of the version numbers is incorrect, check the regex used in the `grep` command and the logic within the `version` function.
- **Failure to Retrieve GitHub Release Info:** If there is an issue with fetching the GitHub release information, verify the network connectivity, the correctness of the curl URLs, and the availability of the `pup` and `jq` utilities to process the HTML.
- **Unintended Update Flag:** If the script incorrectly sets `update=true` even when no new version is available, check the comparison logic for version numbers.
