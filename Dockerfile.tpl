##
# DO NOT EDIT: This file is generated from the Dockerfile.tpl
#
# Pre-stage image to build confd for any kine of architecture we want to support
##
FROM ${BASE_IMAGE} as confd-build

ARG GOPATH=/root/go

RUN apt-get update && \
    DEBIAN_FRONTEND="noninteractive" apt-get -y install tzdata make golang git-core && \
    mkdir -p "${GOPATH}/src/github.com/kelseyhightower" && \
    git clone "${CONFD_SOURCE}" "${GOPATH}/src/github.com/kelseyhightower/confd" && \
    cd "${GOPATH}/src/github.com/kelseyhightower/confd" && \
    git checkout "v${CONFD_VERSION}" && \
    make && \
    make install

##
# Pre-stage image to build jicmp and jicmp6
##
FROM ${BASE_IMAGE} as jicmp-build

# Install build dependencies for JICMP and JICMP6
RUN apt-get update && \
    DEBIAN_FRONTEND="noninteractive" apt-get install --no-install-recommends -y ca-certificates git-core build-essential dh-autoreconf openjdk-8-jdk-headless

# Checkout and build JICMP
RUN git clone "${JICMP_GIT_REPO_URL}" /usr/src/jicmp && \
    cd /usr/src/jicmp && \
    git checkout "${JICMP_VERSION}" && \
    git submodule update --init --recursive && \
    autoreconf -fvi && \
    ./configure && \
    make -j$(nproc)

# Checkout and build JICMP6
RUN git clone "${JICMP6_GIT_REPO_URL}" /usr/src/jicmp6 && \
    cd /usr/src/jicmp6 && \
    git checkout "${JICMP6_VERSION}" && \
    git submodule update --init --recursive && \
    autoreconf -fvi && \
    ./configure && \
    make -j$(nproc)

##
# Assemble deploy base image with jicmp, jicmp6, confd and OpenJDK
##
FROM ${BASE_IMAGE}

# Install OpenJDK 11 and create an architecture independent Java directory
# which can be used as Java Home.
# We need to install inetutils-ping. It is required to get the JNI Pinger to work.
# The JNI Pinger is tested with getprotobyname("icmp") and it is null if inetutils-ping is missing
# To be able to use DGRAM to send ICMP messages we have to give the java binary CAP_NET_RAW capabilities in Linux.
RUN apt-get update && \
    DEBIAN_FRONTEND="noninteractive" apt-get install --no-install-recommends -y "${JAVA_PKG}" curl ca-certificates openssh-client inetutils-ping libcap2-bin tzdata && \
    ln -s /usr/lib/jvm/java-11-openjdk* "${JAVA_HOME}" && \
    rm -rf /var/lib/apt/lists/* && \
    mkdir -p /opt/prom-jmx-exporter && \
    curl "${PROM_JMX_EXPORTER_URL}" --output /opt/prom-jmx-exporter/jmx_prometheus_javaagent.jar

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

LABEL org.opencontainers.image.created="${BUILD_DATE}" \
      org.opencontainers.image.title="OpenNMS deploy based on ${BASE_IMAGE}" \
      org.opencontainers.image.source="${VCS_SOURCE}" \
      org.opencontainers.image.revision="${VCS_REVISION}" \
      org.opencontainers.image.version="${VERSION}" \
      org.opencontainers.image.vendor="The OpenNMS Group, Inc." \
      org.opencontainers.image.authors="OpenNMS Community" \
      org.opencontainers.image.licenses="AGPL-3.0" \
      org.opennms.image.base="${BASE_IMAGE}" \
      org.opennms.image.java.version="${JAVA_PKG_VERSION}" \
      org.opennms.image.java.home="${JAVA_HOME}" \
      org.opennms.image.jicmp.version="${JICMP_VERSION}" \
      org.opennms.image.jicmp6.version="${JICMP6_VERSION}" \
      org.opennms.cicd.branch="${BUILD_BRANCH}" \
      org.opennms.cicd.buildurl="${BUILD_URL}" \
      org.opennms.cicd.buildnumber="${BUILD_NUMBER}"

# Set JAVA_HOME at runtime
ENV JAVA_HOME=${JAVA_HOME}
