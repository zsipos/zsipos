# SPDX-FileCopyrightText: 2019 Stefan Adams <stefan.adams@vipcomag.de>
# SPDX-License-Identifier: GPL-3.0-or-later
DEVSRC      ?= $(ZTOP)/gateware/soc/build_zsipos/software/include/generated/devicetree.dts
DSTDIR      ?= $(ZTOP)/kernel/build_$(BITS)/dts
SEL4MEMSIZE ?= 0x8000000

GENERATED = $(DSTDIR)/devicetree.dtb $(DSTDIR)/linux.dts $(DSTDIR)/sel4.dts $(DSTDIR)/overlay-sel4.dts

all: $(GENERATED)

$(GENERATED): $(DEVSRC) mkdts.py
	mkdir -p $(DSTDIR)
	python mkdts.py $(DEVSRC) $(SEL4MEMSIZE) $(DSTDIR)

clean: 
	@rm -f $(GENERATED)
