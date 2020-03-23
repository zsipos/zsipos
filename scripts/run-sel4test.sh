BBL="$ZTOP/kernel/build_$BITS/sel4test/bbl/bbl"
QEMU=qemu-system-riscv$BITS

$QEMU \
	-kernel $BBL \
	-nographic \
	-machine virt \
	-m 512 \
	-append "console=hvc0" \
	-only-migratable \
	-smp cpus=2 \
	-cpu rv64gcsu-v1.10.0 \
	#-drive file=disk.img,format=raw,if=none,id=disk0 \
	#-device virtio-blk-device,drive=disk0 \
	#-netdev tap,id=n1,ifname=tap0,script=no,downscript=no \
	#-device virtio-net-device,netdev=n1
