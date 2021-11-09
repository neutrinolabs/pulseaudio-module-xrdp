#!/bin/sh

status=0

if [ -n "$XRDP_SESSION" -a -n "$XRDP_SOCKET_PATH" ]; then
    # These values are not present on xrdp versions before v0.9.8
    if [ -z "$XRDP_PULSE_SINK_SOCKET" -o \
         -z "$XRDP_PULSE_SOURCE_SOCKET" ]; then
        displaynum=${DISPLAY##*:}
        displaynum=${displaynum%.*}
        XRDP_PULSE_SINK_SOCKET=xrdp_chansrv_audio_out_socket_$displaynum
        XRDP_PULSE_SOURCE_SOCKET=xrdp_chansrv_audio_in_socket_$displaynum
    fi

    # Don't check for the presence of the sockets, as if the modules
    # are loaded they won't be there

    # Unload modules
    pactl unload-module module-xrdp-sink >/dev/null 2>&1
    pactl unload-module module-xrdp-source >/dev/null 2>&1

    # Reload modules
    if pactl load-module module-xrdp-sink \
           xrdp_socket_path=$XRDP_SOCKET_PATH \
           xrdp_pulse_sink_socket=$XRDP_PULSE_SINK_SOCKET
    then
        echo "- pulseaudio xrdp-sink loaded"
        if pacmd set-default-sink xrdp-sink; then
            echo "- pulseaudio xrdp-sink set as default"
        else
            echo "? Can't set pulseaudio xrdp-sink as default"
        fi
    else
        echo "? Can't load pulseaudio xrdp-sink"
        status=1
    fi

    if pactl load-module module-xrdp-source \
           xrdp_socket_path=$XRDP_SOCKET_PATH \
           xrdp_pulse_source_socket=$XRDP_PULSE_SOURCE_SOCKET
    then
        echo "- pulseaudio xrdp-source loaded"
        if pacmd set-default-source xrdp-source; then
            echo "- pulseaudio xrdp-source set as default"
        else
            echo "? Can't set pulseaudio xrdp-source as default"
        fi
    else
        echo "? Can't load pulseaudio xrdp-source"
        status=1
    fi
fi

exit $status
