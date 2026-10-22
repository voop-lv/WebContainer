ARG BASE_IMAGE=vooplv/webcontainer:core-main
FROM ${BASE_IMAGE}

ENV DEBIAN_FRONTEND=noninteractive

EXPOSE 80
EXPOSE 443

COPY config /temp_config
COPY /install.sh /install.sh
COPY /openresty-release-key.asc /luarocks-release-key.asc /

RUN bash /install.sh \
 && rm -rf /install.sh /temp_config /openresty-release-key.asc /luarocks-release-key.asc

HEALTHCHECK --interval=10s --timeout=5s --start-period=20s --retries=3 CMD health_check

CMD ["webcontainer-init"]
