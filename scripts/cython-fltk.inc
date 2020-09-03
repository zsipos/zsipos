# SPDX-FileCopyrightText: 2019 Stefan Adams <stefan.adams@vipcomag.de>
# SPDX-License-Identifier: GPL-3.0-or-later

FLUID       = $(ZTOP)/software/build_host/fltk/bin/fluid
FLUID_FLAGS = 
FLCFG_FLAGS = --use-images --use-forms


#
# zsipos
#
FLCFG_ZSIPOS = $(ZTOP)/software/build_zsipos/fltk/bin/fltk-config $(FLCFG_FLAGS)

CC_ZSIPOS       = $(shell $(FLCFG_ZSIPOS) --cxx)
CFLAGS_ZSIPOS  += $(shell $(FLCFG_ZSIPOS) --cxxflags)
LDFLAGS_ZSIPOS += $(shell $(FLCFG_ZSIPOS) --ldflags)

#
# 
#
FLCFG_HOST = $(ZTOP)/software/build_host/fltk/bin/fltk-config $(FLCFG_FLAGS)

CC_HOST       = $(shell $(FLCFG_HOST) --cxx)
CFLAGS_HOST  += $(shell $(FLCFG_HOST) --cxxflags)
LDFLAGS_HOST += $(shell $(FLCFG_HOST) --ldflags)



