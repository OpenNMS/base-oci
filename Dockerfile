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
# Pre-stage image to build jicmp and jicmp6
##
FROM ${BASE_IMAGE} as jicmp-build

ARG JICMP_GIT_REPO_URL="https://github.com/opennms/jicmp"
ARG JICMP_GIT_BRANCH_REF="jicmp-2.0.5-1"
ARG JICMP_SRC=/usr/src/jicmp

ARG JICMP6_GIT_REPO_URL="https://github.com/opennms/jicmp6"
ARG JICMP6_GIT_BRANCH_REF="jicmp6-2.0.4-1"
ARG JICMP6_SRC=/usr/src/jicmp6

# Install build dependencies for JICMP and JICMP6
RUN apt-get update && \
    apt-get install -y git-core build-essential dh-autoreconf openjdk-8-jdk-headless

# Checkout and build JICMP
RUN git clone ${JICMP_GIT_REPO_URL} ${JICMP_SRC} && \
    cd ${JICMP_SRC} && \
    git checkout ${JICMP_GIT_BRANCH_REF} && \
    git submodule update --init --recursive && \
    autoreconf -fvi && \
    ./configure && \
    make -j$(nproc)

# Checkout and build JICMP6
RUN git clone ${JICMP6_GIT_REPO_URL} ${JICMP6_SRC} && \
    cd ${JICMP6_SRC} && \
    git checkout ${JICMP6_GIT_BRANCH_REF} && \
    git submodule update --init --recursive && \
    autoreconf -fvi && \
    ./configure && \
    make -j$(nproc)

##
# Assemble deploy base image with jicmp, jicmp6, confd and OpenJDK
##
FROM ${BASE_IMAGE}

ARG JAVA_MAJOR_VERSION=11
ARG JAVA_PKG_VERSION=11.0.6+10-1ubuntu1~19.10.1
ARG JAVA_PKG=openjdk-${JAVA_MAJOR_VERSION}-jre-headless=${JAVA_PKG_VERSION}
ARG JAVA_HOME=/usr/lib/jvm/java

# Install OPenJDK 11 and create an architecture independent Java directory
# which can be used as Java Home.
# We need to install inetutils-ping. It is required to get the JNI Pinger to work.
# The JNI Pinger is tested with getprotobyname("icmp") and it is null if inetutils-ping is missing
RUN apt-get update && \
    apt-get install -y --no-install-recommends ${JAVA_PKG} openssh-client inetutils-ping && \
    ln -s /usr/lib/jvm/java-11-openjdk* ${JAVA_HOME} && \
    rm -rf /var/lib/apt/lists/*

# Install confd
COPY --from=confd-build /usr/local/bin/confd /usr/local/bin/confd

# Install jicmp
RUN mkdir -p /usr/lib/jni
COPY --from=jicmp-build /usr/src/jicmp/.libs/libjicmp.la /usr/lib/jni/
COPY --from=jicmp-build /usr/src/jicmp/.libs/libjicmp.so /usr/lib/jni/
COPY --from=jicmp-build /usr/src/jicmp/jicmp.jar /usr/share/java

# Install jicmp6
COPY --from=jicmp-build /usr/src/jicmp6/.libs/libjicmp6.la /usr/lib/jni/
COPY --from=jicmp-build /usr/src/jicmp6/.libs/libjicmp6.so /usr/lib/jni/
COPY --from=jicmp-build /usr/src/jicmp6/jicmp6.jar /usr/share/java

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
      org.opennms.image.java.version="${JAVA_PKG_VERSION}" \
      org.opennms.image.java.home="${JAVA_HOME}" \
      org.opennms.image.jicmp.version="${JICMP_GIT_BRANCH_REF}" \
      org.opennms.image.jicmp6.version="${JICMP6_GIT_BRANCH_REF}" \
      org.opennms.cicd.buildnumber="${BUILD_NUMBER}" \
      org.opennms.cicd.buildurl="${BUILD_URL}" \
      org.opennms.cicd.branch="${BUILD_BRANCH}"

# Set JAVA_HOME at runtime
ENV JAVA_HOME=${JAVA_HOME}
