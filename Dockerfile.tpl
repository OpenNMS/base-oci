##
# DO NOT EDIT: This file is generated from the Dockerfile.tpl
##

##
# do some common things that all layers use, on top of the Ubuntu base; also
# make sure security updates are installed
##
FROM ${BASE_IMAGE} as core

RUN apt-get update && \
    env DEBIAN_FRONTEND="noninteractive" apt-get install --no-install-recommends -y \
        ca-certificates \
        curl \
        inetutils-ping \
        less \
        libcap2-bin \
        openssh-client \
        rsync \
        tzdata \
        vim-tiny \
    && \
    ln -sf vi /usr/bin/vim && \
    env DEBIAN_FRONTEND="noninteractive" apt-get install --no-install-recommends -y \
        "${JAVA_PKG}" \
    && \
    grep security /etc/apt/sources.list > /tmp/security.sources.list && \
    apt-get update \
        -o Dir::Etc::SourceList=/tmp/security.sources.list && \
    env DEBIAN_FRONTEND="noninteractive" apt-get full-upgrade \
        --no-install-recommends -y -u \
        -o Dir::Etc::SourceList=/tmp/security.sources.list && \
    apt-get clean && \
    rm -rf /var/cache/apt /var/lib/apt/lists/* /tmp/security.sources.list

FROM core as third-party-base

##
# Pre-stage image to build jicmp and jicmp6
##
FROM core as jicmp-build

RUN apt-get update && \
    env DEBIAN_FRONTEND="noninteractive" apt-get install --no-install-recommends -y \
        build-essential \
        dh-autoreconf \
        git-core \
    && \
    env DEBIAN_FRONTEND="noninteractive" apt-get install --no-install-recommends -y \
        openjdk-8-jdk-headless

# Install build dependencies for JICMP and JICMP6
# Checkout and build JICMP
    
RUN git config --global advice.detachedHead false

RUN git clone --depth 1 --branch "${JICMP_VERSION}" "${JICMP_GIT_REPO_URL}" /usr/src/jicmp && \
    cd /usr/src/jicmp && \
    git submodule update --init --recursive --depth 1 && \
    autoreconf -fvi && \
    ./configure && \
    make -j1

# Checkout and build JICMP6
RUN git clone --depth 1 --branch "${JICMP6_VERSION}" "${JICMP6_GIT_REPO_URL}" /usr/src/jicmp6 && \
    cd /usr/src/jicmp6 && \
    git submodule update --init --recursive --depth 1 && \
    autoreconf -fvi && \
    ./configure && \
    make -j1

##
# Assemble deploy base image with jicmp, jicmp6, confd and OpenJDK
##
FROM core

# Install OpenJDK 11 and create an architecture independent Java directory
# which can be used as Java Home.
# We need to install inetutils-ping. It is required to get the JNI Pinger to work.
# The JNI Pinger is tested with getprotobyname("icmp") and it is null if inetutils-ping is missing
# To be able to use DGRAM to send ICMP messages we have to give the java binary CAP_NET_RAW capabilities in Linux.
RUN apt-get update && \
    DEBIAN_FRONTEND="noninteractive" apt-get install --no-install-recommends -y "${JAVA_PKG}" && \
    ln -s /usr/lib/jvm/java-11-openjdk* "${JAVA_HOME}" && \
    rm -rf /var/lib/apt/lists/* && \
    apt-get clean && \
    rm -rf /var/cache/apt && \
    \
    mkdir -p /opt/prom-jmx-exporter && \
    curl "${PROM_JMX_EXPORTER_URL}" --output /opt/prom-jmx-exporter/jmx_prometheus_javaagent.jar && \
    \
    setcap CAP_NET_BIND_SERVICE+ep "${JAVA_HOME}/bin/java" && \
    echo "${JAVA_HOME}/lib/jli" > /etc/ld.so.conf.d/java-latest.conf && \
    ldconfig

# Install confd
RUN if [ "$(uname -m)" = "x86_64" ]; then \
      curl -L "https://github.com/abtreece/confd/releases/download/v0.19.1/confd-v0.19.1-linux-amd64.tar.gz" --output /tmp/confd.tar.gz; \
    elif [ "$(uname -m)" = "armv7l" ]; then \
      curl -L "https://github.com/abtreece/confd/releases/download/v0.19.1/confd-v0.19.1-linux-arm7.tar.gz" --output /tmp/confd.tar.gz; \
    else \
      curl -L "https://github.com/abtreece/confd/releases/download/v0.19.1/confd-v0.19.1-linux-arm64.tar.gz" --output /tmp/confd.tar.gz; \
    fi && \
    cd /usr/bin && \
    tar -xzf /tmp/confd.tar.gz

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
