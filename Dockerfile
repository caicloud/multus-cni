# This Dockerfile is used to build the image available on DockerHub
FROM cargo.caicloud.xyz/library/debian:stretch


Run mkdir -p /usr/src/multus-cni/bin/

WORKDIR /
COPY ./bin/multus /usr/src/multus-cni/bin/

ADD ./images/entrypoint.sh /

ENTRYPOINT ["/entrypoint.sh"]
