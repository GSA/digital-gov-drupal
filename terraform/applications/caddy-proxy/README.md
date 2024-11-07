# Caddy Egress Proxy Server

The Caddy egress proxy server is an application that facilitates communication to the internet from the Cloud.gov environment.

## File structure

- `Caddyfile.tmpl`: Caddy server configuration. Needs to be written to `Caddyfile`, after injecting the proxy username and password. Terraform does this when deploying the application.
- `.docker`
    - `Dockerfile`: Builds the Caddy server binary, with the `forwardproxy` plugin.
    - `Makefile`: Builds a new version of the Caddy binary, then copies the resulting binary to the directory above this one (`../`).
- `start`: Entrypoint script. Creates two files, `allow.acl` and `deny.acl` from two environmental variables `$PROXY_ALLOW` and `$PROXY_DENY`. The variables should be a space delimitated list of domain names. Caddy requires them to being with `*.`.

## Docker

The `.docker` directory, contains a `Makefile` and a `Dockerfile`. To build a new Caddy binary, run the following commands:

```
cd .docker
make
```

A file called `caddy` will be generated in the root directory.