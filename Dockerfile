##
# Pre-stage image to build confd for any kine of architecture we want to support
##
ARG BASE_IMAGE=ubuntu:eoan
FROM ${BASE_IMAGE} as confd-build

ARG CONFD_VERSION="0.16.0"
ARG CONFD_SOURCE="https://github.com/kelseyhightower/confd.git"
ARG GOPATH=/root/go

RUN apt-get update && \
    apt-get install -y golang git-core && \
    mkdir -p ${GOPATH}/src/github.com/kelseyhightower && \
    git clone ${CONFD_SOURCE} ${GOPATH}/src/github.com/kelseyhightower/confd && \
    cd ${GOPATH}/src/github.com/kelseyhightower/confd && \
    git checkout v${CONFD_VERSION} && \
    make && \
    make install

##
# Assemble deploy base image with confd and OpenJDK
##
FROM ${BASE_IMAGE}

ARG JAVA_MAJOR_VERSION=11
ARG JAVA_PKG_VERSION=11.0.6+10-1ubuntu1~19.10.1
ARG JAVA_PKG=openjdk-${JAVA_MAJOR_VERSION}-jre-headless=${JAVA_PKG_VERSION}

# Install OPenJDK 11 and create an architecture independent Java directory
# which can be used as Java Home.
RUN apt-get update && \
    apt-get install -y --no-install-recommends ${JAVA_PKG} openssh-client && \
    ln -s /usr/lib/jvm/java-11-openjdk* /usr/lib/jvm/java && \
    rm -rf /var/lib/apt/lists/*

COPY --from=confd-build /usr/local/bin/confd /usr/local/bin/confd

ARG BUILD_DATE="1970-01-01T00:00:00+0000"
ARG VCS_URL
ARG VCS_REF
ARG VERSION
ARG BUILD_NUMBER
ARG BUILD_URL
ARG BUILD_BRANCH

LABEL org.opencontainers.image.created="${BUILD_DATE}" \
      org.opencontainers.image.title="Ubuntu with OpenJDK ${JAVA_PKG}" \
      org.opencontainers.image.source="${VCS_URL}" \
      org.opencontainers.image.revision="${VCS_REF}" \
      org.opencontainers.image.version="${VERSION}" \
      org.opencontainers.image.vendor="The OpenNMS Group, Inc." \
      org.opencontainers.image.authors="OpenNMS Community" \
      org.opencontainers.image.licenses="AGPL-3.0" \
      org.opennms.image.base="${BASE_IMAGE}:${BASE_IMAGE_VERSION}" \
      org.opennms.cicd.buildnumber="${BUILD_NUMBER}" \
      org.opennms.cicd.buildurl="${BUILD_URL}" \
      org.opennms.cicd.branch="${BUILD_BRANCH}"

ENV JAVA_HOME=/usr/lib/jvm/java
