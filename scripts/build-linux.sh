
echo "building linux ..."

cd "$TOP/kernel"

SRCDIR="`pwd`/linux"
WRKDIR="`pwd`/build/linux"
CONFIG="zsipos"

INITRAMFS="$TOP/kernel/build/initramfs.cpio"

if [ "$1" == "clean" ]
then
	rm -rf "$WRKDIR"
	exit
fi

linuxmake()
{
	make -C "$SRCDIR" ARCH=riscv O="$WRKDIR" \
		CROSS_COMPILE="$CROSS_COMPILE" \
		CONFIG_INITRAMFS_SOURCE="$INITRAMFS" \
		$1 $2
}

if [ ! -f "$WRKDIR/.config" ]
then
	echo "using default config"
	DEFCONFIG=${CONFIG}${BITS}_defconfig
	mkdir -p "$WRKDIR"
	linuxmake $DEFCONFIG
fi

if [ "$1" == "config" ]
then
	linuxmake menuconfig
	linuxmake savedefconfig
	cp "$WRKDIR/defconfig" "$SRCDIR/arch/riscv/configs/${CONFIG}${BITS}_defconfig"
else
	linuxmake -j8 vmlinux
fi

