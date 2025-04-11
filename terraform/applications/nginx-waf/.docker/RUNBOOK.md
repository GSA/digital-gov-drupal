### Runbook for `WAF ModSecurity NGINX plugin`

#### Runbook for Dockerfile and Makefile Integration

##### Introduction
This runbook is designed to guide you through the integration and build process of a custom Nginx ModSecurity plugin for the web application firewall (WAF) functionality. The provided code consists of a `Dockerfile` and a `Makefile`, with the former detailing steps to build the NGINX plugin, and the latter containing instructions to manage the build process with arguments.

##### Technical Breakdown

**Dockerfile**

The `Dockerfile` initializes a Docker image that is based on the Ubuntu `jammy` release. It then installs necessary packages and builds the Nginx web server with the ModSecurity dynamic module. This is achieved through the following steps:

1. **ARG Values Declaration**
   ```
   ARG modsecurity_nginx_version="1.0.3"
   ARG nginx_version="1.25.4"
   ARG ubuntu_version="jammy"
   ```
   These environment variables are important because they allow the builder to specify the exact versions of the components that will be built.
   
      - `modsecurity_nginx_version` is determined by the version of the [OWASP ModSecurity NGINX repo](https://github.com/owasp-modsecurity/ModSecurity-nginx).
      - `nginx_version` is deterimined by the version shipped in version of NGINX buildpack that is in use.  This can be determined by using the `cf buildpacks` command to see what version Cloud.gov is using.  That buildpack version can then be referenced at the [NGINX Buildpack GitHub repository](https://github.com/cloudfoundry/nginx-buildpack/releases) to see what version of NGINX is shipped in that version of the buildpack.
      - `ubuntu_version` is determined by what version of `cflinuxfs` is in use.  As of this documents creation, it is `cflinuxfs4`, based on Ubuntu Jammy.
    
  The ModSecurity plugin needs to be build for the specific version of NGINX running.

2. **Apt Source List Modification**
   ```
   RUN sed -i 's/^# deb-src./deb-src /' /etc/apt/sources.list
   ```
   This ensures that the Dockerfile can download the source packages needed for the installation of Nginx and its dependencies.

3. **Installation of Required Build Tools and Libraries**
   The next step in the `Dockerfile` involves installing various libraries and tools necessary for building and configuring Nginx and ModSecurity.

4. **Cloning and Building ModSecurity**
   ```
   WORKDIR ${modsecurity_path}
   RUN wget https://github.com/SpiderLabs/ModSecurity-nginx/archive/refs/tags/v${modsecurity_nginx_version}.tar.gz
   RUN tar -xf v${modsecurity_nginx_version}.tar.gz && \
       rm -f v${modsecurity_nginx_version}.tar.gz
   ```
   The code downloads and extracts the specific version of ModSecurity-nginx and prepares for dynamic module integration.

5. **Obtaining and Building Nginx Source**
   Moves to Nginx source directory to prepare for installing its build dependencies.
   ```
   WORKDIR /usr/share/nginx/src/
   RUN apt-get build-dep -y nginx
   ```
   The Makefile is then used to download and extract the specified version of Nginx.

6. **Building the Nginx Modules with ModSecurity**
   Using the `configure` script, the `Dockerfile` builds Nginx modules with the specified `modsecurity` module path:
   ```
   RUN ./configure --add-dynamic-module=${modsecurity_path}/ModSecurity-nginx-${modsecurity_nginx_version} --with-compat && \
       make modules && \
       cp ./objs/ngx_http_modsecurity_module.so /ngx_http_modsecurity_module.so
   ```

**Makefile Analysis**

In addition to the `Dockerfile`, a `Makefile` provides a build pipeline to compile the plugin and collect necessary assets into the local filesystem.  This allows for easy building of the WAF plugin by just running the command `make` in the `nginx-waf/.docker` directory.

1. **Building the Docker Image**
   ```
   docker build --platform linux/amd64 --tag nginx-modsecurity --build-arg=modsecurity_nginx_version=${modsecurity_nginx_version} --build-arg=nginx_version=${new_nginx_version} --build-arg=ubuntu_version=${ubuntu_version} .
   ```
   The Makefile references the arguments for the builds and constructs the Docker image.

   If building locally, export the variables `modsecurity_nginx_version`, `nginx_version`, and `ubuntu_version` before running the Makefile.

2. **Copying the Compiled Module**
   ```
   mkdir -p ../modules
   docker cp nginx-vol:/ngx_http_modsecurity_module.so ../modules
   ```
   Once the Docker image build runs, the resulting compiled module (`ngx_http_modsecurity_module.so`) is copied to a local directory specified by `../modules`.

3. **Cleanup**
   The final steps in the `Makefile` involve cleaning up the Docker volume and removing the temporary Docker image.

#### Troubleshooting

- **Error in Dependency Installation**: If you encounter issues during the installation of required libraries, verify that the `deb-src` line in `/etc/apt/sources.list` is correctly modified. This can be checked with the following command:
  ```
  cat /etc/apt/sources.list | grep deb-src
  ```

- **Building Nginx Sources**: Difficulties while building the Nginx sources can be caused by out-of-date sources or lack of necessary build dependencies. Ensure that the `apt-get update && apt-get install -y` commands are run consistently. Consider manually checking and installing missing dependencies.

- **Incorrect Version Compilation**: You might receive warnings about mismatching versions if the environment variables passed to the Docker build (`modsecurity_nginx_version`, `nginx_version`, and `ubuntu_version`) do not match the expected versions inside the Dockerfile statements.

- **Module Compilation Failure**: If there are issues with the dynamic module compilation step (`make` command), review the configuration and build paths to ensure that there are no typos or missing paths declared within the `Dockerfile`. 
