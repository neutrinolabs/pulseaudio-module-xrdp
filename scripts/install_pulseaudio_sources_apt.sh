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

# Builds the pulseaudio sources on Debian/Ubuntu and writes the internal
# pulseaudio files needed to build the xrdp pulseaudio module into a
# single directory

# This script will pollute the machine with all the pulseaudio dependencies
# needed to build the pulseaudio dpkg. If this isn't acceptable, consider
# running this script in a schroot (or similar) wrapper.

# Use '-d <dir>' to specify an alternate directory


set -e  ; # Exit on any error

# Target directory for output files
PULSE_DIR="$HOME/pulseaudio.src"   ; # Default if nothing is specified

# Argument processing
while [ $# -gt 0 ]; do
    arg="$1"
    shift

    case "$arg" in
        -d) if [ $# -gt 0 ]; then
                PULSE_DIR="$1"
                shift
            else
                echo "** $arg needs an argument" >&2
            fi
            ;;
        *)  echo "** Unrecognised argument '$arg'" >&2
    esac
done

if [ ! -d "$PULSE_DIR" ]; then
    # Operating system release ?
    RELEASE="$(lsb_release -si)-$(lsb_release -sr)"
    echo "Building for : $RELEASE"

    # Make sure sources are available
    if ! grep -q '^ *deb-src' /etc/apt/sources.list; then
        sudo sed -i.bak -e 's|^# deb-src|deb-src|' /etc/apt/sources.list
    fi

    sudo apt-get update

    sudo apt-get build-dep -y pulseaudio
    # Install any missing dependencies for this software release
    case "$RELEASE" in
        Ubuntu-16.04)
            sudo apt-get install -y libjson-c-dev
            ;;
    esac

    cd "$(dirname $PULSE_DIR)"
    apt-get source pulseaudio

    build_dir="$(find . -maxdepth 1 -name pulseaudio-[0-9]\*)"
    if [ -z "$build_dir" ]; then
        echo "** Can't find build directory in $(ls)" >&2
        exit 1
    fi

    cd "$build_dir"
    if [ -x ./configure ]; then
        # This version of PA uses autotools to build
	# This command creates ./config.h
        ./configure
    elif [ -f ./meson.build ]; then
        # Meson only
	rm -rf build
	# This command creates ./build/config.h
        meson build
    else
        echo "** Unable to configure pulseaudio from files in $(pwd)" >&2
        false
    fi

    echo "- Removing unnecessary files"
    # We only need .h files...
    find . -type f \! -name \*.h -delete
    # .. in src/ and /build directories
    find . -mindepth 1 -maxdepth 1 \
        -name src -o -name build -o -name config.h \
        -o -exec rm -rf {} +

    echo "- Renaming $(pwd)/$build_dir as $PULSE_DIR"
    cd ..
    mv "$build_dir" "$PULSE_DIR"
fi

exit 0
