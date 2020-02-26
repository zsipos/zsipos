set -e
echo "building linux ..."

cd "$ZTOP/kernel"

SRCDIR="`pwd`/linux"
WRKDIR="`pwd`/build_$BITS/linux"
CONFIGDIR="$SRCDIR/arch/riscv/configs"
DEFCONFIG="zsipos_${BITS}_defconfig"

INITRAMFS="$ZTOP/kernel/build_$BITS/initramfs.cpio"

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
		$*
}

if [ ! -f "$WRKDIR/.config" ]
then
	echo "using default config"
	mkdir -p "$WRKDIR"
	linuxmake $DEFCONFIG
fi

if [ "$1" == "config" ]
then
	linuxmake menuconfig
	linuxmake savedefconfig
	cp "$WRKDIR/defconfig" "$CONFIGDIR/$DEFCONFIG"
	if [ "$BITS" == 64 ]
	then
		echo "CONFIG_ARCH_RV32I=y"   >"$CONFIGDIR/zsipos_32_defconfig"
		cat "$CONFIGDIR/$DEFCONFIG" >>"$CONFIGDIR/zsipos_32_defconfig"
	else
		grep -v "CONFIG_ARCH_RV32I" <"$CONFIGDIR/$DEFCONFIG" >"$CONFIGDIR/zsipos_64_defconfig"
	fi
else
	linuxmake -j8 vmlinux $1
fi

