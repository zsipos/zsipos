# SPDX-FileCopyrightText: 2019 Stefan Adams <stefan.adams@vipcomag.de>
#
# SPDX-License-Identifier: GPL-3.0-or-later

TOP    := $(shell (cd $(CURDIR)/../../../; pwd))
MODULE := rtp

include $(ZTOP)/scripts/cython-zrtpcpp.inc
include $(ZTOP)/scripts/cython-pj.inc
include $(ZTOP)/scripts/cython-makefile.inc

all:: zsipos/libtest host/libtest

zsipos/libtest: libtest.cpp
	$(CC_ZSIPOS) $(CFLAGS_ZSIPOS) $(CFLAGS_COMMON) $(LDFLAGS_ZSIPOS) $(LDFLAGS_COMMON) $< $(LIBS_ZSIPOS) $(LIBS_COMMON) -o $@

host/libtest: libtest.cpp
	$(CC_HOST) $(CFLAGS_HOST) $(CFLAGS_COMMON) $(LDFLAGS_HOST) $(LDFLAGS_COMMON) $< $(LIBS_HOST) $(LIBS_COMMON) -o $@

