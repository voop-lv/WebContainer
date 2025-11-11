FROM debian:bullseye-slim
ENV DEBIAN_FRONTEND=noninteractive

USER root

COPY /core_files/config /config
COPY /core_files/intcmd /intcmd
COPY /core_files/supervisord /vl/supervisord
COPY /install /install

RUN bash /install/install.sh
RUN bash /install/cleanConfig.sh
RUN rm -rf /install