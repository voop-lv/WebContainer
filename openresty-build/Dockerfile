ARG BASE_IMAGE=vooplv/webcontainer:core-main
#FROM ${BASE_IMAGE}
FROM vooplv/webcontainer:core-main

ENV DEBIAN_FRONTEND=noninteractive

EXPOSE 80
EXPOSE 443

COPY config /temp_config
COPY /init.sh /init.sh
COPY /install.sh /install.sh

RUN apt-get install nginx -y
RUN bash /install.sh
RUN rm /install.sh
RUN rm -rf /temp_config

HEALTHCHECK --interval=10s --timeout=5s --start-period=20s --retries=3 CMD health_check

CMD bash /init.sh