
INITRAMFS=$(ZTOP)/kernel/build_$(BITS)/initramfs.cpio
KERNELDIR=$(ZTOP)/kernel/build_$(BITS)/linux
WRKDIR=$(ZTOP)/kernel/build_$(BITS)/busybox
ROOTFS=$(ZTOP)/kernel/build_$(BITS)/rootfs

ifeq ($(BITS), 32)
	CFLAGS=-march=rv32imafdc -mabi=ilp32
	LDFLAGS=$(CFLAGS)
endif

all:	$(INITRAMFS)

$(INITRAMFS): asroot.sh $(ROOTFS)/bin/busybox $(shell find rootfs)
	rm -f $(KERNELDIR)/usr/*
	cp -ar rootfs/* $(ROOTFS)
	fakeroot ./asroot.sh $(ROOTFS) $(INITRAMFS)

$(ROOTFS)/bin/busybox: $(WRKDIR)/busybox
	mkdir -p $(dir $@)
	cp $< $@

$(WRKDIR)/busybox: $(WRKDIR)/.config
	make -C busybox \
		CROSS_COMPILE=$(CROSS_COMPILE) \
		CFLAGS="$(CFLAGS)" \
		LDFLAGS="$(LDFLAGS)" \
		O=$(WRKDIR)

$(WRKDIR)/.config: busybox.config
	mkdir -p $(WRKDIR)
	cp $< $@

clean:
	rm -rf $(INITRAMFS) $(WRKDIR) $(ROOTFS)

