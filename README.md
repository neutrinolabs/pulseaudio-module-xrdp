[![Build Status](https://github.com/neutrinolabs/pulseaudio-module-xrdp/actions/workflows/build.yml/badge.svg)](https://github.com/neutrinolabs/pulseaudio-module-xrdp/actions)
[![Gitter (xrdp)](https://badges.gitter.im/Join%20Chat.svg)](https://gitter.im/neutrinolabs/xrdp-questions)

# Overview
xrdp implements Audio Output redirection using PulseAudio, which is a sound
system used on POSIX operating systems.

The server to client audio redirection is implemented as per **Remote Desktop
Protocol: Audio Output Virtual Channel Extension
[[MS-RDPEA]](https://msdn.microsoft.com/en-us/library/cc240933.aspx)** specs,
which means it is interoperable with any RDP client which implements it
(most of them including: MS RDP clients, FreeRDP).

The client to server audio redirection is implemented as per **Remote Desktop
Protocol: Audio Input Redirection Virtual Channel Extension
[[MS-RDPEAI]](https://msdn.microsoft.com/en-us/library/dd342521.aspx)**
which means it is interoperable with any RDP client which implements it
(most of them including: MS RDP clients, FreeRDP).

# How to build
These modules make use of the internal pulseaudio module API. To build
them you need access to the pulseaudio sources and configuration.

*Be aware that the pulseaudio application development packages provided
with many distributions do not contain the files necessary to use the
pulseaudio module API*. Consequently, the preparation for building these
modules can be a little more involved than just installing development
tools and packages.

Consult the Pulseaudio Wiki for instructions on building the modules
for your platform:-

https://github.com/neutrinolabs/pulseaudio-module-xrdp/wiki

# Install
One the modules have been built, `sudo make install` should do the following:-
- Install the modules to the correct directory
- Install a script `load_pa_modules.sh` to load the modules when a
  session is started.
  On many systems this script is installed by default in
  /usr/libexec/pulseaudio-module-xrdp/
- Install a desktop file `pulseaudio-xrdp.desktop` which will call the
  `load_pa_modules.sh` script when a desktop is loaded.
  On many systems this script is installed by default in
  `/etc/xdg/autostart`

Note that the modules will only be loaded automatically when the desktop
starts if your desktop supports the XDG autostart specification. Most modern
desktops support this.

You can confirm if the modules are properly installed by following command:
```
ls $(pkg-config --variable=modlibexecdir libpulse) | grep xrdp
```

If you can see `module-xrdp-sink.so` and `module-xrdp-source.so`,
PulseAudio modules are properly built and installed.

Enjoy!

# See if it works
The easiest way to test this is to use the `paplay` command to play an
audio file.

You can also do the following:-
- run `pavumeter` in the xrdp session-
- Playback any YouTube video in Firefox.

You'll see "Showing signal levels of **xrdp sink**" and volume meter moving.
