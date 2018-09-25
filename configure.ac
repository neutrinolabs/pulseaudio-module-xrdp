#                                               -*- Autoconf -*-
# Process this file with autoconf to produce a configure script.

AC_PREREQ([2.65])
AC_INIT([pulseaudio-module-xrdp], [0.2], [xrdp-devel@googlegroups.com])
# specify config_ac.h so we don't collide with pulseaudio's config.h
AC_CONFIG_HEADERS([config_ac.h])
AC_CONFIG_SRCDIR([src])
AC_CONFIG_AUX_DIR([build-aux])
AC_CONFIG_MACRO_DIRS([m4])

AM_PROG_AR
AM_INIT_AUTOMAKE([-Wall foreign silent-rules])
AM_SILENT_RULES([yes])

PKG_PROG_PKG_CONFIG
if test "x$PKG_CONFIG" = "x"; then
  AC_MSG_ERROR([pkg-config not found])
fi

m4_ifdef([AM_SILENT_RULES], [AM_SILENT_RULES([yes])])

# get system's pulseaudio version
m4_define([pa_major], [`$PKG_CONFIG --modversion libpulse | cut -d. -f1`])
m4_define([pa_minor], [`$PKG_CONFIG --modversion libpulse | cut -d. -f2`])
# pulseaudio module/lib directory
PA_LIBDIR=`$PKG_CONFIG --variable=libdir libpulse`
PA_MODDIR=`$PKG_CONFIG --variable=modlibexecdir libpulse`
PA_PREFIX=`$PKG_CONFIG --variable=prefix libpulse`

AC_SUBST([PA_MAJOR], [pa_major])
AC_SUBST([PA_MINOR], [pa_minor])
AC_SUBST([PA_MAJORMINOR], [pa_major].[pa_minor])

# Build shared libraries
LT_INIT([shared disable-static])

# Checks for programs.
AC_PROG_CXX
AC_PROG_AWK
AC_PROG_CC
AC_PROG_CPP
AC_PROG_INSTALL
AC_PROG_LN_S
AC_PROG_MAKE_SET

# Checks for libraries.
PKG_CHECK_MODULES([LIBPULSE], [libpulse])

m4_define([PULSE_MSG], [PULSE_DIR not specified. Follow the instructions in README.md.])

AC_ARG_VAR([PULSE_DIR], [pulseaudio source code directory])
AS_IF([test x"$PULSE_DIR" == x""],
cat <<__MSG__
m4_text_box([PULSE_MSG])
__MSG__
AC_MSG_ERROR([PULSE_DIR not specified])
)

# use the prefix as same as pulseaudio
AC_PREFIX_PROGRAM(pulseaudio)

# copied from pulseaudio
AC_ARG_WITH(
    [module-dir],
    [AS_HELP_STRING([--with-module-dir],
        [Directory where to install the modules to (defaults to `pkg-config --variable=modlibexecdir libpulse`)])],
    [modlibexecdir=$withval], [modlibexecdir="${PA_MODDIR}"])
AC_SUBST(modlibexecdir)

# Checks for header files.
AC_CHECK_HEADERS([fcntl.h limits.h netinet/in.h stdlib.h string.h sys/ioctl.h sys/socket.h unistd.h])

# Checks for typedefs, structures, and compiler characteristics.
AC_TYPE_INT64_T
AC_TYPE_SIZE_T
AC_TYPE_UINT32_T

# Checks for library functions.
AC_CHECK_FUNCS([memset socket])

AC_CONFIG_FILES([Makefile
                 src/Makefile])
AC_OUTPUT
