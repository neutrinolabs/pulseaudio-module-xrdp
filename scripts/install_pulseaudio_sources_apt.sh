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
    codename=$(lsb_release -cs)
    echo "Building for : $RELEASE ($codename)"

    # Do any special-case stuff related to repositories
    case $(lsb_release -si) in
        Ubuntu)
            # Enable the universe repository. Don't use add-apt-repository
            # as this has a huge number of dependencies.
            if ! grep -q '^ *[^#].* universe *' /etc/apt/sources.list; then
                echo "- Adding 'universe' repository" >&2
                cp /etc/apt/sources.list /tmp/sources.list
                while read type url suite rest; do
                    if [ "$type" = deb -a "$rest" = main ]; then
                        case "$suite" in
                            $codename | $codename-updates | $codename-security)
                                echo "deb $url $suite universe"
                                ;;
                        esac
                    fi
                done </tmp/sources.list \
                     | sudo tee -a /etc/apt/sources.list >/dev/null
                rm /tmp/sources.list
            fi
            ;;
    esac

    # Make sure sources are available
    for srclst in $(find /etc/apt/ /etc/apt/sources.list.d -maxdepth 1 -type f -name '*.list'); do
	if ! grep -q '^ *deb-src' $srclst; then
            echo "- Adding source repositories" >&2
            cp $srclst /tmp/sources.list
            while read type url suite rest; do
		if [ "$type" = deb ]; then
                    case "$suite" in
			$codename | $codename-updates | $codename-security)
                            echo "deb-src $url $suite $rest"
                            ;;
                    esac
		fi
            done </tmp/sources.list \
		| sudo tee -a $srclst >/dev/null
            rm /tmp/sources.list
	fi
	# remove references to other distro's package sources; needed when running the wrapper in a
	# derivative-distro (like Linux Mint 21.2 'victoria') with --suite option (--suite=jammy).
	sudo sed -i "/$codename/!d" $srclst
	cat $srclst >> /tmp/combined_sources.list # prepare a combined sources.list file
	sudo rm $srclst # remove the *.list file as we will use the combined .list file
    done
    # remove duplicates from the combined source.list in order to prevent apt warnings/errors;
    # this is useful in cases where the user has already configured source code repositories.
    cat /tmp/combined_sources.list | sort | uniq | sudo tee /etc/apt/sources.list > /dev/null

    sudo apt-get update

    # For the CI build on 22.04, it was noted that an incompatible libunwind
    # development package libunwind-14-dev was installed, which prevented
    # installation of the default libunwind-dev package.
    #
    # Remove any libunwind-*-dev package
    pkg_list=`dpkg-query -W -f '${Package} ' 'libunwind-*-dev' 2>/dev/null || :`
    if [ -n "$pkg_list" ]; then
        echo "- Removing package(s) $pkg_list"
        sudo apt-get remove -y $pkg_list
    fi

    sudo apt-get build-dep -y pulseaudio
    # Install any missing dependencies for this software release
    case "$RELEASE" in
        Ubuntu-16.04)
            sudo apt-get install -y libjson-c-dev
            ;;
        Kali-2022*)
            sudo apt-get install -y doxygen
            ;;
        Debian-12)
            # Debian testing build
            case "$codename" in
                bookworm)
                    sudo apt-get install -y doxygen
                    ;;
            esac
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
