ARG BASE_IMAGE=vooplv/webcontainer:core-main
FROM ${BASE_IMAGE}

ENV DEBIAN_FRONTEND=noninteractive

EXPOSE 80
EXPOSE 443

COPY config /temp_config
COPY /install.sh /install.sh

RUN bash /install.sh \
 && rm -rf /install.sh /temp_config

HEALTHCHECK --interval=10s --timeout=5s --start-period=20s --retries=3 CMD health_check

CMD ["webcontainer-init"]
