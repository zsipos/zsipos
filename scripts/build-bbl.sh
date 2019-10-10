
echo "buildling bbl ..."

cd $TOP/kernel

SRCDIR="`pwd`/riscv-pk"
WRKDIR="`pwd`/build/bbl"

if [ "$1" == "clean" ]
then
	rm -rf "$WRKDIR"
	exit
fi

mkdir -p "$WRKDIR"

cd "$WRKDIR"

"$SRCDIR/configure" \
	--host=riscv64-unknown-linux-gnu \
	--with-arch=rv64imac \
	--with-payload=../linux/vmlinux \
	--with-mem-start=0x80000000 \
	--enable-logo

make

riscv64-unknown-linux-gnu-objcopy -O binary bbl ../boot.bin


