#!/bin/sh
#
# xrdp: A Remote Desktop Protocol server.
#
# Copyright (C) 2021 Matt Burt, all xrdp contributors
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

# Wrapper to call install_pulseaudio_sources.sh and tidy up afterwards
#
# The following command line switches are supported, for systems based on
# Debian or Ubuntu:-
#
# 1) --mirror=    Specify an alternative mirror for debootstrap
# 2) --keyring=   Specify an alternative keyring for debootstrap
# 3) --suite=     Specify an alternative suite for debootstrap
#
#    The first two of these are are needed for systems with their own
#    mirrors and signing keys (i.e. Raspberry PI OS).
#
#    --suite is useful for systems which report their own codename for
#    `lsb_release -c`, but are otherwise based on a standard distro. For
#    example Linux Mint 20.04 reports 'una', but is largely based on
#    Ubuntu 'focal'

# ---------------------------------------------------------------------------
# G L O B A L S
# ---------------------------------------------------------------------------
# Where the output files are going
PULSE_DIRNAME=pulseaudio.src
PULSE_DIR=$HOME/$PULSE_DIRNAME

# Absolute path to the script we're wrapping. This picks it up from
# the same directory this file is in
WRAPPED_SCRIPT=$(cd $(dirname $0) && pwd)/install_pulseaudio_sources_apt.sh

# The buildroot directory. Choose fast, temporary storage if available
BUILDROOT=/var/lib/pa-build/$USER

# Extra packages to install in the build root which the wrapped script
# may be using. These are packages available by default when using
# GitHub actions
WRAPPED_SCRIPT_DEPS="sudo lsb-release"

# -----------------------------------------------------------------------------
# S U I T E   E X I S T S
#
# Does the specified debootstrap suite exist?
# -----------------------------------------------------------------------------
SuiteExists()
{
    [ -f "/usr/share/debootstrap/scripts/$1" ]
}

# -----------------------------------------------------------------------------
# I N S T A L L   R E Q U I R E D   P A C K A G E S
#
# Installs packages required for the build on the host machine
# -----------------------------------------------------------------------------
InstallRequiredPackages()
{
    set -- \
        /usr/sbin/debootstrap   debootstrap \
        /usr/bin/schroot        schroot \
        /usr/bin/lsb_release    lsb-release

    pkgs=
    while [ $# -ge 2 ]; do
        if [ ! -x $1 ]; then
            pkgs="$pkgs $2"
        fi
        shift 2
    done

    if [ -n "$pkgs" ]; then
        echo "- Need to install packages :$pkgs"
        echo
        echo "  These can be removed when this script completes with:-"
        echo "  sudo apt-get purge$pkgs && apt-get autoremove"
        echo
        sudo apt-get install -y $pkgs
    fi
}

# -----------------------------------------------------------------------------
# R U N   W R A P P E D   S C R I P T
#
# Runs the wrapped build script using schroot
#
# This function definition uses () rather than {} to create an extra
# sub-process where we can run 'set -e' without affecting the parent
#
# Parameters : <script> [<script params>...]
# -----------------------------------------------------------------------------
RunWrappedScript()
(
    # In this sub-process, fail on error
    set -e

    # Define default args for running program
    # -c : Define the schroot config to use
    # -d : Directory to switch to before running command
    schroot="schroot -c pa-build-$USER -d /build"

    # Install extra dependencies
    $schroot -u root -- apt-get update
    $schroot -u root -- apt-get install -y $WRAPPED_SCRIPT_DEPS

    # Allow normal user to sudo without a password
    $schroot -u root -- \
        /bin/sh -c "echo '$USER ALL=(ALL) NOPASSWD:ALL'>/etc/sudoers.d/nopasswd-$USER"
    $schroot -u root -- chmod 400 /etc/sudoers.d/nopasswd-$USER

    # Call the wrapped script
    $schroot -- "$@"
)

# -----------------------------------------------------------------------------
# M A I N
# -----------------------------------------------------------------------------
debootstrap_mirror=""
debootstrap_switches=""
debootstrap_suite=""

# Parse command line switches
while [ -n "$1" ]; do
    case "$1" in
        --mirror=*)
            debootstrap_mirror="${1#--mirror=}"
            ;;
        --keyring=*)
            file="${1#--keyring=}"
            if [ -f "$file" ]; then
                debootstrap_switches="$debootstrap_switches $1"
            else
                echo "** Ignoring missing keyring $1" >&2
            fi
            ;;
        --suite=*)
            debootstrap_suite="${1#--suite=}"
            if ! SuiteExists "$debootstrap_suite"; then
                echo "** Unsupported suite '$debootstrap_suite'" >&2
                exit 1
            fi
            ;;
        *)  echo "** Unrecognised parameter '$1'" >&2
            exit 1
    esac
    shift
done

# Start with a few sanity checks
if [ -d $PULSE_DIR ]; then
    echo "** Target directory $PULSE_DIR already exists" >&2
    exit 0
fi

if [ ! -x $WRAPPED_SCRIPT ]; then
    echo "** Can't find wrapped script $WRAPPED_SCRIPT" >&2
    exit 1
fi

if [ -e $BUILDROOT ]; then
    echo "** Remove old build root $BUILDROOT before running this script"
    exit 1
fi

# Do we need extra packages?
InstallRequiredPackages || exit $?

# We should be able to determine the suite now, if it's not specified
if [ -z "$debootstrap_suite" ]; then
    debootstrap_suite=$(lsb_release -cs) ; # e.g. 'bullseye'
    if [ -z "$debootstrap_suite" ]; then
        echo "** Can't determine current suite" >&2
        exit 1
    fi

    if ! SuiteExists "$debootstrap_suite" ; then
        echo "** Current distro '$debootstrap_suite' does not appear to be supported by debootstrap" >&2
        echo "   Need --suite switch?" >&2
        exit 1
    fi
fi

# Create the build root
log=/var/tmp/pa-build-$USER-debootstrap.log
echo "- Creating $debootstrap_suite build root. Log file in $log"
sudo debootstrap \
    $debootstrap_switches \
    $debootstrap_suite $BUILDROOT "$debootstrap_mirror" >$log 2>&1 || {
    echo "** debootstrap failed. Check log file $log" >&2
    exit 1
}

# Create the config file for schroot
schroot_conf=/etc/schroot/chroot.d/pa-build-$USER.conf
echo "- Creating schroot config file $schroot_conf"
{
    echo "[pa-build-$USER]"
    echo "description=Build PA on current system for $USER"
    echo "directory=$BUILDROOT"
    echo "root-users=$USER"
    echo "users=$USER"
    echo "type=directory"
} | sudo tee $schroot_conf >/dev/null || exit $?

# Copy some files to the build root
for file in $(find /etc/apt/ /etc/apt/sources.list.d -maxdepth 1 -type f -name '*.list'); do
    echo "- Copying $file to the root"
    sudo install -m 0644 $file $BUILDROOT/$file || exit $?
done

# Create a separate directory in $BUILDROOT to hold the build
# artefacts.
#
# We used to do the build on the user's home directory, but this
# isn't supported by schroot out-of-the-box on all configurations -
# see https://github.com/neutrinolabs/pulseaudio-module-xrdp/issues/76
echo "- Creating the build directory /build"
sudo install -d --mode=0775 --owner=$USER --group=$(id -g) \
    $BUILDROOT/build || exit $?

# Copy the wrapped script to the buildroot root
echo "- Copying the wrapped script to the build directory"
sudo install -m 755 $WRAPPED_SCRIPT $BUILDROOT/build/wrapped_script || exit $?

# Run the wrapped script
log=/var/tmp/pa-build-$USER-schroot.log
echo "- Building PA sources. Log file in $log"
RunWrappedScript /build/wrapped_script  -d /build/$PULSE_DIRNAME >$log 2>&1 || {
    echo "** schroot failed. Check log file $log" >&2
    exit 1
}

# Done! Copy the resulting directory out of the build root
echo "- Copying sources out of the build root"
cp -pr $BUILDROOT/build/$PULSE_DIRNAME $PULSE_DIR || exit $?

# Remove the schroot config file as its no longer needed
echo "- Removing schroot config file and build root"
sudo rm -rf $schroot_conf $BUILDROOT

echo "- All done. Configure PA xrdp module with PULSE_DIR=$PULSE_DIR"
exit 0
