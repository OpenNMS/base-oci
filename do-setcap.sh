#!/bin/sh

set -e

if [ -z "${JAVA_HOME}" ] || [ ! -e "${JAVA_HOME}" ]; then
    echo '${JAVA_HOME} is not set or does not exist!'
    exit 1
fi

NOCAP_HOME="/usr/lib/jvm/java-nocap"

create_link() {
    if [ ! -e "${NOCAP_HOME}/$1" ]; then
        ln -s "${JAVA_HOME}/$1" "${NOCAP_HOME}/$1"
    fi
}

mkdir -p "${NOCAP_HOME}"
cp -R "${JAVA_HOME}/bin" "/usr/lib/jvm/java-nocap/"
for SUBDIR in conf docs legal lib man release; do
    create_link "${SUBDIR}"
done

setcap "CAP_NET_BIND_SERVICE=+ep CAP_NET_RAW=+ep" "${JAVA_HOME}/bin/java"
echo "${JAVA_HOME}/lib/jli" > /etc/ld.so.conf.d/java-latest.conf
ldconfig
