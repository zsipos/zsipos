BBL=../build_64/bbl/bbl
QEMU=/opt/riscv/bin/qemu-system-riscv64

$QEMU \
	-kernel $BBL \
	-nographic \
	-machine virt \
	-m 4095 \
	-append "console=hvc0" \
	-only-migratable \
	-smp cpus=2 \
	#-drive file=disk.img,format=raw,if=none,id=disk0 \
	#-device virtio-blk-device,drive=disk0 \
	#-netdev tap,id=n1,ifname=tap0,script=no,downscript=no \
	#-device virtio-net-device,netdev=n1
