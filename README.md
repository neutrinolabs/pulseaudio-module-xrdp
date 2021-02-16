[![Build Status](https://travis-ci.org/neutrinolabs/pulseaudio-module-xrdp.svg?branch=devel)](https://travis-ci.org/neutrinolabs/pulseaudio-module-xrdp)

The latest version of this document can be found at wiki.

* https://github.com/neutrinolabs/pulseaudio-module-xrdp/wiki/README


# Overview
xrdp implements Audio Output redirection using PulseAudio, which is a sound
system used on POSIX operating systems.

The server to client audio redirection is implemented as per **Remote Desktop
Protocol: Audio Output Virtual Channel Extension
[[MS-RDPEA]](https://msdn.microsoft.com/en-us/library/cc240933.aspx)** specs,
which means it is interoperable with any RDP client which implements it
(most of them including: MS RDP clients, FreeRDP).

However, our Microphone redirection (client to server) implementation is
proprietary and doesn't implement the
[[MS-RDPEAI]](https://msdn.microsoft.com/en-us/library/dd342521.aspx)
specs. Its only supported by the following clients so far: NeutrinoRDP client
and rdesktop.

Here is how to build pulseaudio modules for your distro, so you can have audio
support through xrdp.

In this instruction, pulseaudio version is **11.1**. You need to **replace the
version number in this instruction** if your environment has different
versions. You can find out your pulseaudio version executing the following
command:

    pulseaudio --version

or

    pkg-config --modversion libpulse

# How to build

## Debian 9 / Ubuntu

This instruction also should be applicable to the Ubuntu family.

### Prerequisites

Some build tools and package development tools are required. Make sure install
the tools.

    apt install build-essential dpkg-dev

### Prepare & build

Install pulseaudio and requisite packages to build pulseaudio.

    apt install pulseaudio
    apt build-dep pulseaudio

Fetch the pulseaudio source. You'll see `pulseaudio-11.1` directory in your
current directory.

    apt source pulseaudio

Enter into the directory and build the pulseaudio package.

    cd pulseaudio-11.1
    ./configure

Finally, let's build xrdp source / sink modules. You'll have two .so files
`module-xrdp-sink.so` and `module-xrdp-source.so`.

    git clone https://github.com/neutrinolabs/pulseaudio-module-xrdp.git
    cd pulseaudio-module-xrdp
    ./bootstrap && ./configure PULSE_DIR=/path/to/pulseaudio-11.1
    make

## CentOS 7.x (7.5 or later requires this build procedure)

### Prerequisites

Some build tools and package development tools are required. Make sure install
the tools.

    yum groupinstall "Development Tools"
    yum install rpmdevtools yum-utils
    rpmdev-setuptree

### Prepare & build

Install pulseaudio and requisite packages to build pulseaudio.

    yum install pulseaudio pulseaudio-libs pulseaudio-libs-devel
    yum-builddep pulseaudio

Fetch the pulseaudio source and extract. You'll see `~/rpmbuild/BUILD/

    yumdownloader --source pulseaudio
    rpm --install pulseaudio*.src.rpm

Build the pulseaudio source. In this phase, pulseaudio is not necessarily needed to be built but
configured however there's no way to do only configure.

    rpmbuild -bb --noclean ~/rpmbuild/SPECS/pulseaudio.spec

Finally, let's build xrdp source / sink modules. You'll have two .so files
`module-xrdp-sink.so` and `module-xrdp-source.so`.

    git clone https://github.com/neutrinolabs/pulseaudio-module-xrdp.git
    cd pulseaudio-module-xrdp
    ./bootstrap && ./configure PULSE_DIR=~/rpmbuild/BUILD/pulseaudio-10.0
    make
*******************************************************************************
*******************************************************************************

## Fedora 33 Workstation
Linux/Fedora version
uname -a
Linux localhost.localdomain 5.10.14-200.fc33.x86_64 #1 SMP Sun Feb 7 19:59:31 UTC 2021 x86_64 x86_64 x86_64 GNU/Linux


*******************************************************************************
Overview

Install Fedora 33 Workstation from DVD/USB
 -Select optional software groups
   C Development Tools and Libraries
   Development Tools
   System Tools

Read the following:
 -https://github.com/neutrinolabs/xrdp/blob/devel/README.md
   Requirements for building xrdp (only used for dependencies)

 -https://github.com/neutrinolabs/pulseaudio-module-xrdp/wiki/README
   How to install and configure pulseaudio source files
   How to install and build xrdp modules for pulseaudio

 -https://github.com/neutrinolabs/xrdp/wiki/Audio-Output-Virtual-Channel-support-in-xrdp
   How xrdp selects pulseaudio modules (older info. did not do any of the suggestions.)

Install pulseaudio source
 -Download source
 -Run ./configure to customize for your machine/version

Install xrdp module source
 -Download source
 -Run ./bootstrap to pre-build compile environment
 -Run ./configure make files
 -Make modules
 -Install modules in system directories

Note:
 -You cannot be logged in from a GUI session (on the hardware console) and xrdp at the same time.

 
*******************************************************************************
Installation steps from neutrino labs pulseaudio-module-xrdp readme.md file
 -Changing 11.1 in example to 14.0 for Fedora 33 Workstation
 -Adding additional steps for Fedora 33 Workstation

# sudo -s  (home-dir is now /root)

Add the following packages:
 (from https://github.com/neutrinolabs/xrdp/blob/devel/README.md)
 dnf install -y tigervnc-server openssl-devel pam-devel
 dnf install -y libX11-devel libXfixes-devel libXrandr-devel

 (from many attempts at ./configure)
 dnf install -y libjpeg-devel fuse-devel perl-libxml-perl libtool-ltdl-devel
 dnf install -y libcap-devel libsndfile-devel libgudev-devel
 dnf install -y dbus-devel dbus-doc.noarch dbus-tests
 dnf install -y speex-devel speex-tools speexdsp-devel
 dnf install -y systemd-devel systemd-tests
 dnf install -y sbc-devel
 dnf install -y pulseaudio-libs-devel


*******************************************************************************
Find pulseaudio version
# pulseaudio --version
pulseaudio 14.0-rebootstrapped

Check if xrdp modules are already installed
# pulseaudio --dump-modules
  note: no xrdp modules were listed on my system


*******************************************************************************
Retrieve and configure the pulseaudio source-version that matches your installed-version
see the (extensive) list source-versions at https://freedesktop.org/software/pulseaudio/releases
#
# wget https://freedesktop.org/software/pulseaudio/releases/pulseaudio-14.0.tar.xz
# tar xf pulseaudio-14.0.tar.xz
# cd pulseaudio-14.0
# ./configure
# cd ..


*******************************************************************************
Retrieve, configure, and compile the source for the xrdp pulseaudio module.
Note: use a fully-qualified path name for ./configure
#
# git clone https://github.com/neutrinolabs/pulseaudio-module-xrdp.git
# cd pulseaudio-module-xrdp
# ./bootstrap
# ./configure PULSE_DIR='/root/pulseaudio-14.0'
# make
# make install


*******************************************************************************
Verify modules are installed
# ls $(pkg-config --variable=modlibexecdir libpulse)
...
module-xrdp-sink.la		module-xrdp-sink.so		module-xrdp-source.la		module-xrdp-source.so

Verify pulseaudio can use the xrdp modules.
# pulseaudio --dump-modules
module-xrdp-sink                        xrdp sink
module-xrdp-source                      xrdp source

Verify Fedora can see xrdp sink/source as audio options
 -Close any remote or console sessions to your host
 -Open a new xrdp session to your host
 -Click:
   Activities -> Show Applications -> Settings -> Sound
   Output Device should be "xrdp sink"
   Test button opens a dialog with "Left" and "Right" tests
   Clicking on "Left" and "Right" should make sound from your corresponding speaker
*******************************************************************************
*******************************************************************************


## Other distro

First off, find out your pulseaudio version using `pulseaudio --version`
command. Download the tarball of the pulseaudio version that you have.

* https://freedesktop.org/software/pulseaudio/releases/

After downloading the tarball, extract the tarball and `cd` into the source
directory, then run `./configure`.

    wget https://freedesktop.org/software/pulseaudio/releases/pulseaudio-11.1.tar.xz
    tar xf pulseaudio-11.1.tar.xz
    cd pulseaudio-11.1
    ./configure

If additional packages are required to run `./configure`, install requisite
packages depending on your environment.

Finally, let's build xrdp source / sink modules. You'll have two .so files
`module-xrdp-sink.so` and `module-xrdp-source.so`.

    git clone https://github.com/neutrinolabs/pulseaudio-module-xrdp.git
    cd pulseaudio-module-xrdp
    ./bootstrap && ./configure PULSE_DIR=/path/to/pulseaudio-11.1
    make

# Install

Just `make install` should install built modules to the correct directory.

You can confirm if the modules properly installed by following command:
```
ls $(pkg-config --variable=modlibexecdir libpulse)
```

If you can see lots of `module-*.so` and `module-xrdp-sink.so`,
`module-xrdp-source.so`, PulseAudio modules should be properly built and
installed.

`module-xrdp-sink.so` and `module-xrdp-source.so` may be installed to the
target directory, these files are not necessary and you can remove them safely.

Enjoy!

# See if it works

To see if it works, run `pavumeter` in the xrdp session.  Playback any YouTube
video in Firefox. You'll see "Showing signal levels of **xrdp sink**" and
volume meter moving.
