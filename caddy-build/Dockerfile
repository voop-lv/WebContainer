ARG BASE_IMAGE=vooplv/webcontainer:core-main

# Caddy's newest release, built from source like supercronic: the current Go toolchain and the newest
# golang.org/x/net and x/crypto instead of whatever the upstream release binary was linked with. Every module
# is verified against sum.golang.org.
FROM golang:1.27-alpine AS caddy
RUN apk add --no-cache curl \
 && ver="$(curl -fsSLI -o /dev/null -w '%{url_effective}' https://github.com/caddyserver/caddy/releases/latest | sed -n 's|.*/tag/v||p')" \
 && [ -n "${ver}" ] \
 && mkdir /src && cd /src \
 && printf 'package main\n\nimport (\n\tcaddycmd "github.com/caddyserver/caddy/v2/cmd"\n\t_ "github.com/caddyserver/caddy/v2/modules/standard"\n)\n\nfunc main() { caddycmd.Main() }\n' > main.go \
 && go mod init caddy \
 && go get "github.com/caddyserver/caddy/v2@v${ver}" golang.org/x/net@latest golang.org/x/crypto@latest \
 && go mod tidy \
 && CGO_ENABLED=0 go build -trimpath -ldflags '-s -w' -o /caddy . \
 && /caddy version | grep -q "^v${ver} "

FROM ${BASE_IMAGE}

EXPOSE 80
EXPOSE 443

COPY --from=caddy /caddy /usr/bin/caddy
COPY config /temp_config
COPY /install.sh /install.sh

RUN bash /install.sh \
 && rm -rf /install.sh /temp_config

HEALTHCHECK --interval=10s --timeout=5s --start-period=20s --retries=3 CMD health_check

CMD ["webcontainer-init"]
