# WAF (Nginx) Server

The WAF (Nginx) server is an ingress proxy, routing traffic to various internal applications based on the URI.

## File structure

- `.docker`
    - `Dockerfile`: Builds the Nginx `modsecurity` plugin.
    - `Makefile`: Builds a new version of the Caddy binary, then copies the resulting binary to the `modules` directory above this one (`../modules`).
- `modsecurity`: modsecurity configuration, utilizing OWASP CRS.
    - https://github.com/SpiderLabs/ModSecurity
    - https://github.com/SpiderLabs/ModSecurity-nginx
    - https://github.com/coreruleset/coreruleset/
- `modules`: Contains the compiled Nginx modsecurity binary.
- `nginx`: Contains Nginx configuration files.
    - `conf.d`: The main configuration file to load.
    - `snippets`: Contains .tmpl files for Nginx, which have variable replacements, along with the main owasp modsecurity configuration.
- `packages`: Contains the `corereuleset` tar.gz archive and the `libmodsecurity3` Debian file.
- `public`: Basic index web page the default buildpack configuration uses.
- `apt.yml`: Installs additional packages into the buildpack during staging.
- `entrypoint`: Sleeps to hold a process open.
- `init`: Configures the buildpack to function as a WAF instead of a basic web server.
- `modsecurity.conf`: The main configuration file for modsecurity.
- `nginx.conf`: The main configuration file for Nginx.
- `start`: The buildpack entrypoint. Runs the `init` script, starts Nginx, then runs `entrypoint` to keep the container open.

## Docker

The `.docker` directory, contains a `Makefile` and a `Dockerfile`. To build a new Caddy binary, run the following commands:

```
cd .docker
make
```

A file called `ngx_http_modsecurity_module.so` will be generated in directory `modules`, in the root directory.