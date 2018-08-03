#                                               -*- Autoconf -*-
# Process this file with autoconf to produce a configure script.

AC_PREREQ([2.65])
AC_INIT([pulseaudio-module-xrdp], [0.1], [xrdp-devel@googlegroups.com])
# specify module-config.h so we don't collide with pulseaudio's config.h
AC_CONFIG_HEADERS([module-config.h])
AC_CONFIG_SRCDIR([src])
AC_CONFIG_AUX_DIR([build-aux])
AC_CONFIG_MACRO_DIRS([m4])

AM_PROG_AR
AM_INIT_AUTOMAKE([-Wall foreign silent-rules])
AM_SILENT_RULES([yes])

m4_ifdef([AM_SILENT_RULES], [AM_SILENT_RULES([yes])])

# get system's pulseaudio version
m4_define([pa_major], [`echo $(pulseaudio --version) | cut -d' ' -f2 | cut -d. -f1`])
m4_define([pa_minor], [`echo $(pulseaudio --version) | cut -d' ' -f2 | cut -d. -f2`])

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
PKG_CHECK_MODULES([XRDP], [xrdp >= 0.9.0])
AC_SUBST(XRDP_CFLAGS)

m4_define([PULSE_MSG], [pulseaudio source code directory not specified.
    please download the required sources from:
    https://freedesktop.org/software/pulseaudio/releases/
    and run ./configure PULSE_DIR=<path to sources>])

AC_ARG_VAR([PULSE_DIR], [pulseaudio source code directory])
AS_IF([test x"$PULSE_DIR" == x""],
    AC_MSG_ERROR([m4_text_box([PULSE_MSG])])
    )

# copied from pulseaudio
AC_ARG_WITH(
    [module-dir],
    [AS_HELP_STRING([--with-module-dir],
    	[Directory where to install the modules to (defaults to ${libdir}/pulse-${PA_MAJORMINOR}/modules)])],
    [modlibexecdir=$withval], [modlibexecdir="${libdir}/pulse-${PA_MAJORMINOR}/modules"])
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
