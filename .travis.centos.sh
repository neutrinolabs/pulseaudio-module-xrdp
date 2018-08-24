#!/usr/bin/env bash

SRC_DIR=${PWD}

cd /tmp
yum install -y epel-release
yum install -y wget sudo
yum install -y pulseaudio pulseaudio-libs pulseaudio-libs-devel
yum install -y rpmdevtools yum-utils
yum-builddep -y pulseaudio
yum groupinstall -y "Development Tools"

sed -i.bak \
  -e 's/\(^%wheel\s*ALL=(ALL)\s*ALL\)/# \1/' \
  -e 's/^#\s\(%wheel\s*ALL=(ALL)\s*NOPASSWD:\s*ALL\)/\1/' \
  /etc/sudoers
useradd -m -G wheel travis
# Docker issue #2259
chown -R travis:travis ~travis

PULSE_VER=$(pkg-config --modversion libpulse)
sudo -u travis yumdownloader --source pulseaudio || exit 1
sudo -u travis rpm  --install pulseaudio\*.src.rpm || exit 1
sudo -u travis rpmbuild -bb --noclean ~travis/rpmbuild/SPECS/pulseaudio.spec || exit 1

cd ${SRC_DIR}
sudo -u travis ./bootstrap && ./configure PULSE_DIR=~travis/rpmbuild/BUILD/pulseaudio-${PULSE_VER} && make || exit 1
