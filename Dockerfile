FROM debian:trixie-slim
ENV DEBIAN_FRONTEND=noninteractive

USER root

COPY /core_files/scripts /scripts
COPY /core_files/config /config
COPY /core_files/intcmd /intcmd
COPY /core_files/supervisord /vl/supervisord
COPY /install /install

RUN bash /install/install.sh \
 && bash /install/cleanConfig.sh \
 && rm -rf /install
