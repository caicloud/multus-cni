# This Dockerfile is used to build the image available on DockerHub
FROM cargo.caicloudprivatetest.com/caicloud/debian:jessie


Run mkdir -p /usr/src/multus-cni/bin/

WORKDIR /
COPY ./bin/multus /usr/src/multus-cni/bin/

ADD ./images/entrypoint.sh /

ENTRYPOINT ["/entrypoint.sh"]
