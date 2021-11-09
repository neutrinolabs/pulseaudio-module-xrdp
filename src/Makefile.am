AM_CFLAGS = -O2   \
            -fPIC \
            -I $(PULSE_CONFIG_DIR)      \
            -I $(PULSE_DIR)/src  \
            $(XRDP_CFLAGS)

AM_LDFLAGS = -module \
             -avoid-version

modlibexec_LTLIBRARIES = module-xrdp-sink.la module-xrdp-source.la

module_xrdp_sink_la_SOURCES = module-xrdp-sink.c
module_xrdp_sink_la_CFLAGS = $(AM_CFLAGS)
module_xrdp_sink_la_LDFLAGS = $(AM_LDFLAGS)

module_xrdp_source_la_SOURCES = module-xrdp-source.c
module_xrdp_source_la_CFLAGS = $(AM_CFLAGS)
module_xrdp_source_la_LDFLAGS = $(AM_LDFLAGS)
