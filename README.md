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

`module-xrdp-sink.la` and `module-xrdp-source.so` may be installed to the
target directory, these files are not necessary and you can remove them safely.

Enjoy!

# See if it works

To see if it works, run `pavumeter` in the xrdp session.  Playback any YouTube
video in Firefox. You'll see "Showing signal levels of **xrdp sink**" and
volume meter moving.
