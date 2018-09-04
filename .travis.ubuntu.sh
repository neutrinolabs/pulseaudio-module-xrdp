#!/usr/bin/env bash

SRC_DIR=${PWD}

cd /tmp
sed -i.bak -e 's|^# deb-src|deb-src|' /etc/apt/sources.list

apt update
apt install -y build-essential dpkg-dev libpulse-dev pulseaudio pkg-config
apt install -y g++ clang

apt install -y pulseaudio
apt build-dep -y pulseaudio
apt source pulseaudio

PULSE_VER=$(pkg-config --modversion libpulse)

cd pulseaudio-${PULSE_VER}
./configure || exit 1

cd ${SRC_DIR}
./bootstrap && ./configure PULSE_DIR=/tmp/pulseaudio-${PULSE_VER} && make
