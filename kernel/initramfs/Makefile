INITRAMFS=$(ZTOP)/kernel/build_$(BITS)/initramfs.cpio
KERNELDIR=$(ZTOP)/kernel/build_$(BITS)/linux
WRKDIR=$(ZTOP)/kernel/build_$(BITS)/busybox
ROOTFS=$(ZTOP)/kernel/build_$(BITS)/rootfs
#BUILDROOT=$(ZTOP)/system/buildroot/buildroot/output/target
#FSCKEXT4=$(BUILDROOT)/sbin/fsck.ext4
#LIBLIST1=ld-linux-riscv64-lp64.so.1 libblkid.so.1 libuuid.so.1 libdl.so.2 libc.so.6
#LIBLIST2=libext2fs.so.2 libcom_err.so.2 libe2p.so.2

ifeq ($(BITS), 32)
	CFLAGS=-march=rv32imafdc -mabi=ilp32
	LDFLAGS=$(CFLAGS)
endif

all:	$(INITRAMFS)

$(INITRAMFS): asroot.sh $(ROOTFS)/bin/busybox $(shell find rootfs)
	rm -f $(KERNELDIR)/usr/*
	cp -ar rootfs/* $(ROOTFS)
	#mkdir -p $(ROOTFS)/sbin $(ROOTFS)/lib $(ROOTFS)/usr/lib
	#for i in $(LIBLIST1); do cp -L $(BUILDROOT)/lib/$$i $(ROOTFS)/lib; done
	#for i in $(LIBLIST2); do cp -L $(BUILDROOT)/usr/lib/$$i $(ROOTFS)/usr/lib; done
	#cp $(FSCKEXT4) $(ROOTFS)/sbin
	fakeroot ./asroot.sh $(ROOTFS) $(INITRAMFS)

$(ROOTFS)/bin/busybox: $(WRKDIR)/busybox
	mkdir -p $(dir $@)
	cp $< $@

$(WRKDIR)/busybox: $(WRKDIR)/.config
	make -C busybox \
		CROSS_COMPILE=riscv64-unknown-linux-gnu- \
		CFLAGS="$(CFLAGS)" \
		LDFLAGS="$(LDFLAGS)" \
		O=$(WRKDIR)

$(WRKDIR)/.config: busybox.config
	mkdir -p $(WRKDIR)
	cp $< $@

clean:
	rm -rf $(INITRAMFS) $(WRKDIR) $(ROOTFS)

