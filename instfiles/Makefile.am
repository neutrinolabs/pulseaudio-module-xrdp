EXTRA_DIST = \
   load_pa_modules.sh \
   pulseaudio-xrdp.desktop.in

#
# substitute directories in service file
#
CLEANFILES= \
   pulseaudio-xrdp.desktop

SUBST_VARS = sed \
   -e 's|@pkglibexecdir[@]|$(pkglibexecdir)|g'

subst_verbose = $(subst_verbose_@AM_V@)
subst_verbose_ = $(subst_verbose_@AM_DEFAULT_V@)
subst_verbose_0 = @echo "  SUBST    $@";

SUFFIXES = .in
.in:
	$(subst_verbose)$(SUBST_VARS) $< > $@

#
# files for all platforms
#

# Don't use sysconfdir for this one as it won't work!
xdgautostartdir=/etc/xdg/autostart

xdgautostart_DATA = \
  pulseaudio-xrdp.desktop

pkglibexec_SCRIPTS = \
  load_pa_modules.sh
