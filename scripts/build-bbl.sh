set -e
echo "building bbl ..."

cd "$ZTOP/kernel"
D=`pwd`

SRCDIR="`pwd`/riscv-pk"
WRKDIR="`pwd`/build_$BITS/bbl"

build-dts.sh $1

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
		--with-sel4-payload=../../sel4/build_${BITS}_sel4zsipos/elfloader/elfloader \
		--with-sel4-memsize=0x8000000 \
		--with-linux-payload=../linux/vmlinux \
		--with-devicetree="../dts/linux.dts" 
fi

make



