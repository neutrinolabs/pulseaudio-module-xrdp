#!/usr/bin/env bash

SRC_DIR=${PWD}

cd /tmp
yum install -y epel-release
yum install -y xrdp xrdp-devel xrdp-selinux wget
yum install -y pulseaudio pulseaudio-libs pulseaudio-libs-devel
yum-builddep -y pulseaudio
yum groupinstall -y "Development Tools"

PULSE_VER=$(pkg-config --modversion libpulse)

# not to make traffic on upstream server
wget http://distcache.freebsd.org/ports-distfiles/pulseaudio-${PULSE_VER}.tar.xz
tar xf pulseaudio-${PULSE_VER}.tar.xz
cd pulseaudio-${PULSE_VER}
./configure || exit 1

cd ${SRC_DIR}
./bootstrap && ./configure PULSE_DIR=/tmp/pulseaudio-${PULSE_VER} && make
