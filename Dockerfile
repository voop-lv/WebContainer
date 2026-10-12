# supercronic is a Go binary; building it here instead of downloading the release keeps the Go
# stdlib current (release binaries lag behind Go security fixes) and verifies the module checksum.
FROM golang:1.27-trixie AS supercronic
RUN CGO_ENABLED=0 go install github.com/aptible/supercronic@v0.2.49

FROM debian:trixie-slim
ENV DEBIAN_FRONTEND=noninteractive

USER root

COPY --from=supercronic /go/bin/supercronic /usr/local/bin/supercronic
COPY /core_files/scripts /scripts
COPY /core_files/config /config
COPY /core_files/intcmd /intcmd
COPY /core_files/supervisord /vl/supervisord
COPY /install /install

RUN bash /install/install.sh \
 && bash /install/cleanConfig.sh \
 && rm -rf /install
