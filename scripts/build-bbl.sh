set -e
echo "buildling bbl ..."

cd "$ZTOP/kernel"
D=`pwd`

SRCDIR="`pwd`/riscv-pk"
WRKDIR="`pwd`/build_$BITS/bbl"

if [ "$1" == "clean" ]
then
	rm -rf "$WRKDIR"
	exit
fi

mkdir -p "$WRKDIR"

cd "$WRKDIR"

if [ ! -f config.status ]
then
	"$SRCDIR/configure" \
		--host="$ZTC_PREFIX" \
		--with-arch=rv${BITS}imac \
		--with-mem-start=0x80000000 \
		--with-payload=../../test/build/elfloader/elfloader \
		--with-devicetree="$D/qemu.dts" \
		--with-payload2=../linux/vmlinux \
		--with-memsize-sel4=0x8000000 \
                --enable-print-device-tree
fi

make



