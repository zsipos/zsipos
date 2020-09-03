# SPDX-FileCopyrightText: 2019 Stefan Adams <stefan.adams@vipcomag.de>
# SPDX-License-Identifier: GPL-3.0-or-later

#
# Makefile for cython module.
# Just include and set $(MODULE) to the desired module name.
# Code must reside in a directory named $(MODULE)
#

all::

CYTHON           = cython
CYTHON_FLAGS    += -3 --cplus --fast-fail -I. -X c_string_type=unicode,c_string_encoding=utf8
CYTHON_INCLUDES += $(wildcard *.pxd) $(wildcard *.pxi)

CFLAGS_COMMON  += -fpic -pthread -std=c++11 $(TC_DBGFLAGS) 
LDFLAGS_COMMON += -fpic -pthread -Wl,--as-needed -Wl,--no-undefined
LIBS_COMMON    += -luuid -lz -lssl -lcrypto 

clean::
	rm -rf zsipos host

#
# zsipos
#
MODULE_ZSIPOS    = zsipos/$(MODULE).so
CC_ZSIPOS        = $(ZTC_CXX)
CFLAGS_ZSIPOS    += \
	-I$(ZTC_SYSROOT)/usr/include \
	-I$(ZTC_SYSROOT)/usr/include/python3.8
LIBS_ZSIPOS      += -lpython3.8

all:: $(MODULE_ZSIPOS)

.PRECIOUS: zsipos/$(MODULE).cpp

zsipos/$(MODULE).cpp: $(MODULE).pyx $(CYTHON_INCLUDES) $(CYTHON_DEPENDENCIES)
	mkdir -p zsipos
	echo >zsipos/__init__.py
	$(CYTHON) $(CYTHON_FLAGS) -o $@ $< 

zsipos/$(MODULE).o: zsipos/$(MODULE).cpp
	$(CC_ZSIPOS) $(CFLAGS_ZSIPOS) $(CFLAGS_COMMON) -o $@ -c $<

zsipos/$(MODULE).so: zsipos/$(MODULE).o 
	$(CC_ZSIPOS) $(LDFLAGS_COMMON) $? $(LDFLAGS_ZSIPOS) $(LIBS_ZSIPOS) $(LIBS_COMMON) -shared -o $@


#
# host
#
MODULE_HOST = host/$(MODULE).so
CC_HOST     = g++
CFLAGS_HOST += -I/usr/include/python$(HOST_PYTHON_VERSION)
LIBS_HOST   += -lpython$(HOST_PYTHON_VERSION)m

all:: $(MODULE_HOST)

.PRECIOUS: host/$(MODULE).cpp

host/$(MODULE).cpp: $(MODULE).pyx $(CYTHON_INCLUDES) $(CYTHON_DEPENDENCIES)
	mkdir -p host
	echo >host/__init__.py
	$(CYTHON) $(CYTHON_FLAGS) -o $@ $< 

host/$(MODULE).o: host/$(MODULE).cpp
	$(CC_HOST) -c $(CFLAGS_HOST) $(CFLAGS_COMMON) -o $@ $<

host/$(MODULE).so: host/$(MODULE).o 
	$(CC_HOST) $(LDFLAGS_COMMON) $? $(LDFLAGS_HOST) $(LIBS_HOST) $(LIBS_COMMON) -shared -o $@

