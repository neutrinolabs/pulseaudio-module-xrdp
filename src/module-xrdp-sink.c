/***
  pulse sink module for xrdp

  Copyright 2004-2008 Lennart Poettering
  Copyright (C) 2008 Nokia Corporation and/or its subsidiary(-ies).
  Copyright (C) 2013-2021 Jay Sorg, Neutrino Labs, and all contributors.

  PulseAudio is free software; you can redistribute it and/or modify
  it under the terms of the GNU Lesser General Public License as published
  by the Free Software Foundation; either version 2 of the License,
  or (at your option) any later version.

  PulseAudio is distributed in the hope that it will be useful, but
  WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
  General Public License for more details.

  You should have received a copy of the GNU Lesser General Public License
  along with PulseAudio; if not, write to the Free Software
  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307
  USA.
***/

// config.h from pulseaudio sources
#ifdef HAVE_CONFIG_H
#include <config.h>
#endif

#include <unistd.h>
#include <errno.h>
#include <netinet/in.h>
#include <netinet/tcp.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <sys/types.h>

#include <stdlib.h>
#include <sys/stat.h>
#include <stdio.h>
#include <errno.h>
#include <string.h>
#include <fcntl.h>
#include <unistd.h>
#include <limits.h>
#include <sys/ioctl.h>
#include <poll.h>

#include <pulse/rtclock.h>
#include <pulse/timeval.h>
#include <pulse/xmalloc.h>

#include <pulsecore/core-error.h>
#include <pulsecore/sink.h>
#include <pulsecore/module.h>
#include <pulsecore/core-util.h>
#include <pulsecore/modargs.h>
#include <pulsecore/log.h>
#include <pulsecore/thread.h>
#include <pulsecore/thread-mq.h>
#include <pulsecore/rtpoll.h>

/* defined in pulse/version.h */
#if PA_PROTOCOL_VERSION > 28
/* these used to be defined in pulsecore/macro.h */
typedef bool pa_bool_t;
#define FALSE ((pa_bool_t) 0)
#define TRUE (!FALSE)
#else
#endif

#include "module-xrdp-sink-symdef.h"


PA_MODULE_AUTHOR("Jay Sorg");
PA_MODULE_DESCRIPTION("xrdp sink");
PA_MODULE_VERSION(PACKAGE_VERSION);
PA_MODULE_LOAD_ONCE(FALSE);
PA_MODULE_USAGE(
        "sink_name=<name for the sink> "
        "sink_properties=<properties for the sink> "
        "format=<sample format> "
        "rate=<sample rate> "
        "channels=<number of channels> "
        "channel_map=<channel map> "
        "xrdp_socket_path=<path to XRDP sockets> "
        "xrdp_pulse_sink_socket=<name of sink socket>");

#define DEFAULT_SINK_NAME "xrdp-sink"
#define BLOCK_USEC 30000
//#define BLOCK_USEC (PA_USEC_PER_SEC * 2)

/* support for the set_state_in_io_thread callback was added in 11.99.1 */
#if defined(PA_CHECK_VERSION) && PA_CHECK_VERSION(11, 99, 1)
#define USE_SET_STATE_IN_IO_THREAD_CB
#else
#undef USE_SET_STATE_IN_IO_THREAD_CB
#endif

struct userdata {
    pa_core *core;
    pa_module *module;
    pa_sink *sink;

    pa_thread *thread;
    pa_thread_mq thread_mq;
    pa_rtpoll *rtpoll;

    pa_usec_t block_usec;
    pa_usec_t timestamp;
    pa_usec_t failed_connect_time;
    pa_usec_t last_send_time;

    int fd; /* unix domain socket connection to xrdp chansrv */
    int skip_bytes;

    char *sink_socket;
};

static const char* const valid_modargs[] = {
    "sink_name",
    "sink_properties",
    "format",
    "rate",
    "channels",
    "channel_map",
    "xrdp_socket_path",
    "xrdp_pulse_sink_socket",
    NULL
};

static int close_send(struct userdata *u);

static int sink_process_msg(pa_msgobject *o, int code, void *data,
                            int64_t offset, pa_memchunk *chunk) {

    struct userdata *u = PA_SINK(o)->userdata;
    pa_usec_t now;
    long lat;

    switch (code) {

        case PA_SINK_MESSAGE_SET_VOLUME:
            pa_log_debug("sink_process_msg: PA_SINK_MESSAGE_SET_VOLUME");
            break;

        case PA_SINK_MESSAGE_SET_MUTE:
            pa_log_debug("sink_process_msg: PA_SINK_MESSAGE_SET_MUTE");
            break;

        case PA_SINK_MESSAGE_GET_LATENCY:
            pa_log_debug("sink_process_msg: PA_SINK_MESSAGE_GET_LATENCY");
            now = pa_rtclock_now();
            lat = u->timestamp > now ? u->timestamp - now : 0ULL;
            pa_log_debug("sink_process_msg: lat %ld", lat);
            *((pa_usec_t*) data) = lat;
            return 0;

        case PA_SINK_MESSAGE_GET_REQUESTED_LATENCY:
            pa_log_debug("sink_process_msg: PA_SINK_MESSAGE_GET_REQUESTED_LATENCY");
            break;

        case PA_SINK_MESSAGE_SET_STATE:
            pa_log_debug("sink_process_msg: PA_SINK_MESSAGE_SET_STATE");
            if (PA_PTR_TO_UINT(data) == PA_SINK_RUNNING) /* 0 */ {
                pa_log("sink_process_msg: running");

                u->timestamp = pa_rtclock_now();
            } else {
                pa_log("sink_process_msg: not running");
                close_send(u);
            }
            break;

        default:
            pa_log_debug("sink_process_msg: code %d", code);

    }

    return pa_sink_process_msg(o, code, data, offset, chunk);
}

#ifdef USE_SET_STATE_IN_IO_THREAD_CB
/* Called from the IO thread. */
static int sink_set_state_in_io_thread_cb(pa_sink *s,
                                          pa_sink_state_t new_state,
                                          pa_suspend_cause_t new_suspend_cause)
{
    struct userdata *u;

    pa_assert(s);
    pa_assert_se(u = s->userdata);

    if (s->thread_info.state == PA_SINK_SUSPENDED || s->thread_info.state == PA_SINK_INIT)
    {
        if (PA_SINK_IS_OPENED(new_state))
        {
            pa_log_debug("sink_set_state_in_io_thread_cb: set timestamp");
            u->timestamp = pa_rtclock_now();
        }
    }

    return 0;
}
#endif /* USE_SET_STATE_IN_IO_THREAD_CB */

static void sink_update_requested_latency_cb(pa_sink *s) {
    struct userdata *u;
    size_t nbytes;

    pa_sink_assert_ref(s);
    pa_assert_se(u = s->userdata);

    u->block_usec = pa_sink_get_requested_latency_within_thread(s);

    if (u->block_usec == (pa_usec_t) -1) {
        u->block_usec = s->thread_info.max_latency;
    }
    nbytes = pa_usec_to_bytes(u->block_usec, &s->sample_spec);
    pa_sink_set_max_rewind_within_thread(s, nbytes);
    pa_sink_set_max_request_within_thread(s, nbytes);
}

static void process_rewind(struct userdata *u, pa_usec_t now) {
    size_t rewind_nbytes, in_buffer;
    pa_usec_t delay;

    pa_assert(u);

    rewind_nbytes = u->sink->thread_info.rewind_nbytes;

    if (!PA_SINK_IS_OPENED(u->sink->thread_info.state) || rewind_nbytes <= 0)
        goto do_nothing;

    pa_log_debug("Requested to rewind %lu bytes.", (unsigned long) rewind_nbytes);

    if (u->timestamp <= now)
        goto do_nothing;

    delay = u->timestamp - now;
    in_buffer = pa_usec_to_bytes(delay, &u->sink->sample_spec);

    if (in_buffer <= 0)
        goto do_nothing;

    if (rewind_nbytes > in_buffer)
        rewind_nbytes = in_buffer;

    pa_sink_process_rewind(u->sink, rewind_nbytes);
    u->timestamp -= pa_bytes_to_usec(rewind_nbytes, &u->sink->sample_spec);

    pa_log_debug("Rewound %lu bytes.", (unsigned long) rewind_nbytes);
    return;

do_nothing:

    pa_sink_process_rewind(u->sink, 0);
}

struct header {
    int code;
    int bytes;
};

static int get_display_num_from_display(const char *display_text) {
    int index;
    int mode;
    int host_index;
    int disp_index;
    int scre_index;
    int display_num;
    char host[256];
    char disp[256];
    char scre[256];

    if (display_text == NULL) {
        return 0;
    }
    memset(host, 0, 256);
    memset(disp, 0, 256);
    memset(scre, 0, 256);

    index = 0;
    host_index = 0;
    disp_index = 0;
    scre_index = 0;
    mode = 0;

    while (display_text[index] != 0) {
        if (display_text[index] == ':') {
            mode = 1;
        } else if (display_text[index] == '.') {
            mode = 2;
        } else if (mode == 0) {
            host[host_index] = display_text[index];
            host_index++;
        } else if (mode == 1) {
            disp[disp_index] = display_text[index];
            disp_index++;
        } else if (mode == 2) {
            scre[scre_index] = display_text[index];
            scre_index++;
        }
        index++;
    }

    host[host_index] = 0;
    disp[disp_index] = 0;
    scre[scre_index] = 0;
    display_num = atoi(disp);
    return display_num;
}

static int lsend(int fd, char *data, int bytes) {
    int sent = 0;
    int error;
    while (sent < bytes) {
        error = send(fd, data + sent, bytes - sent, 0);
        if (error < 1) {
            return error;
        }
        sent += error;
    }
    return sent;
}

static int data_send(struct userdata *u, pa_memchunk *chunk) {
    char *data;
    int bytes;
    int sent;
    int fd;
    struct header h;
    struct sockaddr_un s;

    if (u->fd == -1) {
        if (u->failed_connect_time != 0) {
            if (pa_rtclock_now() - u->failed_connect_time < 1000000) {
                return 0;
            }
        }
        fd = socket(PF_LOCAL, SOCK_STREAM, 0);
        memset(&s, 0, sizeof(s));
        s.sun_family = AF_UNIX;
        pa_strlcpy(s.sun_path, u->sink_socket, sizeof(s.sun_path));
        pa_log_debug("trying to connect to %s", s.sun_path);

        if (connect(fd, (struct sockaddr *)&s,
                    sizeof(struct sockaddr_un)) != 0) {
            u->failed_connect_time = pa_rtclock_now();
            pa_log_debug("Connected failed");
            close(fd);
            return 0;
        }
        u->failed_connect_time = 0;
        pa_log("Connected ok fd %d", fd);
        u->fd = fd;
    }

    bytes = chunk->length;
    pa_log_debug("bytes %d", bytes);

    h.code = 0;
    h.bytes = bytes + 8;
    if (lsend(u->fd, (char*)(&h), 8) != 8) {
        pa_log("data_send: send failed");
        close(u->fd);
        u->fd = -1;
        return 0;
    } else {
        pa_log_debug("data_send: sent header ok bytes %d", bytes);
    }

    data = (char*)pa_memblock_acquire(chunk->memblock);
    data += chunk->index;
    sent = lsend(u->fd, data, bytes);
    pa_memblock_release(chunk->memblock);

    if (sent != bytes) {
        pa_log("data_send: send failed sent %d bytes %d", sent, bytes);
        close(u->fd);
        u->fd = -1;
        return 0;
    }

    return sent;
}

static int close_send(struct userdata *u) {
    struct header h;

    pa_log("close_send:");
    if (u->fd == -1) {
        return 0;
    }
    h.code = 1;
    h.bytes = 8;
    if (lsend(u->fd, (char*)(&h), 8) != 8) {
        pa_log("close_send: send failed");
        close(u->fd);
        u->fd = -1;
        return 0;
    } else {
        pa_log_debug("close_send: sent header ok");
    }
    return 8;
}

static void process_render(struct userdata *u, pa_usec_t now) {
    pa_memchunk chunk;
    int request_bytes;

    pa_assert(u);
    pa_log_debug("process_render: u->block_usec %llu", (unsigned long long) u->block_usec);
    while (u->timestamp < now + u->block_usec) {
        request_bytes = u->sink->thread_info.max_request;
        request_bytes = MIN(request_bytes, 16 * 1024);
        pa_sink_render(u->sink, request_bytes, &chunk);
        if (u->sink->thread_info.state == PA_SINK_RUNNING) {
            data_send(u, &chunk);
        }
        pa_memblock_unref(chunk.memblock);
        u->timestamp += pa_bytes_to_usec(chunk.length, &u->sink->sample_spec);
    }
}

static void thread_func(void *userdata) {

    struct userdata *u = userdata;

    pa_assert(u);

    pa_log_debug("Thread starting up");

    pa_thread_mq_install(&u->thread_mq);

    u->timestamp = pa_rtclock_now();

    for (;;) {
        pa_usec_t now = 0;
        int ret;

        if (PA_SINK_IS_OPENED(u->sink->thread_info.state)) {
            now = pa_rtclock_now();
        }
        if (PA_UNLIKELY(u->sink->thread_info.rewind_requested)) {
            process_rewind(u, now);
        }
        /* Render some data and write it to the socket */
        if (PA_SINK_IS_OPENED(u->sink->thread_info.state)) {
            if (u->timestamp <= now) {
                process_render(u, now);
            }
            pa_rtpoll_set_timer_absolute(u->rtpoll, u->timestamp);
        } else {
            pa_rtpoll_set_timer_disabled(u->rtpoll);
        }

        /* Hmm, nothing to do. Let's sleep */
#if defined(PA_CHECK_VERSION) && PA_CHECK_VERSION(6, 0, 0)
        if ((ret = pa_rtpoll_run(u->rtpoll)) < 0) {
#else
        if ((ret = pa_rtpoll_run(u->rtpoll, TRUE)) < 0) {
#endif
            goto fail;
        }

        if (ret == 0) {
            goto finish;
        }
    }
fail:
    /* If this was no regular exit from the loop we have to continue
     * processing messages until we received PA_MESSAGE_SHUTDOWN */
    pa_asyncmsgq_post(u->thread_mq.outq, PA_MSGOBJECT(u->core),
                      PA_CORE_MESSAGE_UNLOAD_MODULE, u->module, 0,
                      NULL, NULL);
    pa_asyncmsgq_wait_for(u->thread_mq.inq, PA_MESSAGE_SHUTDOWN);

finish:
    pa_log_debug("Thread shutting down");
}

static void set_sink_socket(pa_modargs *ma, struct userdata *u) {
    const char *socket_dir;
    const char *socket_name;
    char default_socket_name[64];
    size_t nbytes;

    socket_dir = pa_modargs_get_value(ma, "xrdp_socket_path",
                                      getenv("XRDP_SOCKET_PATH"));
    if (socket_dir == NULL || socket_dir[0] == '\0') {
        socket_dir = "/tmp/.xrdp";
    }

    socket_name = pa_modargs_get_value(ma, "xrdp_pulse_sink_socket",
                                       getenv("XRDP_PULSE_SINK_SOCKET"));
    if (socket_name == NULL || socket_name[0] == '\0')
    {
        int display_num = get_display_num_from_display(getenv("DISPLAY"));

        pa_log_debug("Could not obtain sink_socket from environment.");
        snprintf(default_socket_name, sizeof(default_socket_name),
                 "xrdp_chansrv_audio_out_socket_%d", display_num);
        socket_name = default_socket_name;
    }

    nbytes = strlen(socket_dir) + 1 + strlen(socket_name) + 1;
    u->sink_socket = pa_xmalloc(nbytes);
    snprintf(u->sink_socket, nbytes, "%s/%s", socket_dir, socket_name);
}

int pa__init(pa_module*m) {
    struct userdata *u = NULL;
    pa_sample_spec ss;
    pa_channel_map map;
    pa_modargs *ma = NULL;
    pa_sink_new_data data;
    size_t nbytes;

    pa_assert(m);

    if (!(ma = pa_modargs_new(m->argument, valid_modargs))) {
        pa_log("Failed to parse module arguments.");
        goto fail;
    }

    ss = m->core->default_sample_spec;
    map = m->core->default_channel_map;
    if (pa_modargs_get_sample_spec_and_channel_map(ma, &ss, &map,
                         PA_CHANNEL_MAP_DEFAULT) < 0) {
        pa_log("Invalid sample format specification or channel map");
        goto fail;
    }

    m->userdata = u = pa_xnew0(struct userdata, 1);
    u->core = m->core;
    u->module = m;
    u->rtpoll = pa_rtpoll_new();
    pa_thread_mq_init(&u->thread_mq, m->core->mainloop, u->rtpoll);

    pa_sink_new_data_init(&data);
    data.driver = __FILE__;
    data.module = m;
    pa_sink_new_data_set_name(&data,
          pa_modargs_get_value(ma, "sink_name", DEFAULT_SINK_NAME));
    pa_sink_new_data_set_sample_spec(&data, &ss);
    pa_sink_new_data_set_channel_map(&data, &map);
    pa_proplist_sets(data.proplist, PA_PROP_DEVICE_DESCRIPTION, "xrdp sink");
    pa_proplist_sets(data.proplist, PA_PROP_DEVICE_CLASS, "abstract");

    if (pa_modargs_get_proplist(ma, "sink_properties", data.proplist,
                                PA_UPDATE_REPLACE) < 0) {
        pa_log("Invalid properties");
        pa_sink_new_data_done(&data);
        goto fail;
    }

    u->sink = pa_sink_new(m->core, &data,
                          PA_SINK_LATENCY | PA_SINK_DYNAMIC_LATENCY);
    pa_sink_new_data_done(&data);

    if (!u->sink) {
        pa_log("Failed to create sink object.");
        goto fail;
    }

    u->sink->parent.process_msg = sink_process_msg;
#ifdef USE_SET_STATE_IN_IO_THREAD_CB
    u->sink->set_state_in_io_thread = sink_set_state_in_io_thread_cb;
#endif
    u->sink->update_requested_latency = sink_update_requested_latency_cb;
    u->sink->userdata = u;

    pa_sink_set_asyncmsgq(u->sink, u->thread_mq.inq);
    pa_sink_set_rtpoll(u->sink, u->rtpoll);

    u->block_usec = BLOCK_USEC;
    pa_log_debug("3 block_usec %llu", (unsigned long long) u->block_usec);
    nbytes = pa_usec_to_bytes(u->block_usec, &u->sink->sample_spec);
    pa_sink_set_max_rewind(u->sink, nbytes);
    pa_sink_set_max_request(u->sink, nbytes);

    set_sink_socket(ma, u);

    u->fd = -1;

#if defined(PA_CHECK_VERSION)
#if PA_CHECK_VERSION(0, 9, 22)
    if (!(u->thread = pa_thread_new("xrdp-sink", thread_func, u))) {
#else
    if (!(u->thread = pa_thread_new(thread_func, u))) {
#endif
#else
    if (!(u->thread = pa_thread_new(thread_func, u))) {
#endif
        pa_log("Failed to create thread.");
        goto fail;
    }

    pa_sink_set_latency_range(u->sink, 0, BLOCK_USEC);

    pa_sink_put(u->sink);

    pa_modargs_free(ma);

    return 0;

fail:
    if (ma) {
        pa_modargs_free(ma);
    }

    pa__done(m);

    return -1;
}

int pa__get_n_used(pa_module *m) {
    struct userdata *u;

    pa_assert(m);
    pa_assert_se(u = m->userdata);

    return pa_sink_linked_by(u->sink);
}

void pa__done(pa_module*m) {
    struct userdata *u;

    pa_assert(m);

    if (!(u = m->userdata)) {
        return;
    }

    if (u->sink) {
        pa_sink_unlink(u->sink);
    }

    if (u->thread) {
        pa_asyncmsgq_send(u->thread_mq.inq, NULL, PA_MESSAGE_SHUTDOWN,
                          NULL, 0, NULL);
        pa_thread_free(u->thread);
    }

    pa_thread_mq_done(&u->thread_mq);

    if (u->sink) {
        pa_sink_unref(u->sink);
    }

    if (u->rtpoll) {
        pa_rtpoll_free(u->rtpoll);
    }

    if (u->fd >= 0)
    {
        close(u->fd);
        u->fd = -1;
    }

    pa_xfree(u->sink_socket);
    pa_xfree(u);
}
