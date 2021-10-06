#!/usr/bin/env bash

set -e  ; # Exit on any error
cd $HOME

if [ ! -d pulseaudio.src ]; then
    sudo sed -i.bak -e 's|^# deb-src|deb-src|' /etc/apt/sources.list

    sudo apt-get update

    sudo apt-get build-dep -y pulseaudio
    apt-get source pulseaudio

    pulse_dir=$(find . -maxdepth 1 -name pulseaudio-\*)
    if [[ -z $pulse_dir ]]; then
        echo "** Can't find pulse dir in $(ls)" >&2
        exit 1
    fi

    cd $pulse_dir
    ./configure
    cd ..
    mv $pulse_dir pulseaudio.src
fi

exit 0
