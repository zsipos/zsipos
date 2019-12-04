set -e
echo "building riscv toolchain .."

cd "$ZTOP/toolchain"

if [ "$1" == "clean" ]
then
	rm -rf riscv64 build
	exit 0
fi

mkdir -p build/riscv-gdb
cd build
../riscv-gnu-toolchain/configure --prefix="$ZTC_TOOLS_DIR" --enable-multilib --enable-linux
if [ "ZTC_TYPE" != "native" ]
then
	echo "toolchain type is $ZTC_TYPE, only build gdb"
	make $J build-gdb
else
	make $J 
fi


