TOP    := $(shell (cd $(CURDIR)/../../../; pwd))
MODULE := gui

CYTHON_DEPENDENCIES += gui.fl fltk.cpp

all:: zsipos/gui.cxx host/gui.cxx

zsipos/gui.cxx: gui.fl
	mkdir -p zsipos
	(cd zsipos; $(FLUID) $(FLUID_FLAGS) -c ../$?)

host/gui.cxx: gui.fl
	mkdir -p host
	(cd host; $(FLUID) $(FLUID_FLAGS) -c ../$?)

include $(TOP)/scripts/cython-fltk.inc
include $(TOP)/scripts/cython-makefile.inc

