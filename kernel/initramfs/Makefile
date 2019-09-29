
INITRAMFS=$(TOP)/kernel/build/initramfs.cpio
KERNELDIR=$(TOP)/kernel/build/linux
WRKDIR=$(TOP)/kernel/build/busybox
ROOTFS=$(TOP)/kernel/build/rootfs

all:	$(INITRAMFS)

$(INITRAMFS): asroot.sh $(ROOTFS)/bin/busybox $(shell find rootfs)
	rm -f $(KERNELDIR)/usr/*
	cp -ar rootfs/* $(ROOTFS)
	fakeroot ./asroot.sh $(ROOTFS) $(INITRAMFS)

$(ROOTFS)/bin/busybox: $(WRKDIR)/busybox
	mkdir -p $(dir $@)
	cp $< $@

$(WRKDIR)/busybox: $(WRKDIR)/.config
	make -C busybox CROSS_COMPILE=$(CROSS_COMPILE) O=$(WRKDIR)

$(WRKDIR)/.config: busybox.config
	mkdir -p $(WRKDIR)
	cp $< $@

clean:
	rm -rf $(INITRAMFS) $(WRKDIR) $(ROOTFS)

