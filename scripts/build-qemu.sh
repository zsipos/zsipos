set -e
echo "buildind qemu .."

cd "$ZTOP/toolchain"

WRKDIR=build/qemu

if [ "$1" == "clean" ]
then
	rm -rf "$WRKDIR"
	exit 0
fi

mkdir -p "$WRKDIR"
cd "$WRKDIR"
../../riscv-gnu-toolchain/qemu/configure \
	--prefix="$RISCV" \
	--static --target-list="riscv32-linux-user riscv64-linux-user" \
	--disable-tools \
	--disable-docs \
	--disable-system 
make 
make install


