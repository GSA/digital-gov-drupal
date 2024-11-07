# https://hub.docker.com/_/caddy/tags?page=1&name=builder

FROM caddy:2.7-builder AS builder

RUN xcaddy build \
--with github.com/caddyserver/forwardproxy@master

RUN cp /usr/bin/caddy /caddy

HEALTHCHECK NONE
USER caddy
