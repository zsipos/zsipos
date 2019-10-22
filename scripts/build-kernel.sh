
echo "building kernel ..."

build-initramfs.sh $1
build-linux.sh $1
build-bbl.sh $1

if [ -d /tftpboot ] && [ -w /tftpboot/boot.bin ]
then
	cp "$TOP/kernel/build_$BITS/boot.bin" /tftpboot
	echo "boot.bin installed to /tftpboot."
fi
