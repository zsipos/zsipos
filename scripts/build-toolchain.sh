set -e
echo "building riscv toolchain .."

cd "$ZTOP/toolchain"

if [ "$1" == "clean" ]
then
	rm -rf riscv64 build
	exit 0
fi

if [ "ZTC_TYPE" != "native" ]
then
	echo "toolchain type is $ZTC_TYPE, no toolchain build needed"
	exit 0
fi

mkdir -p build
cd build
../riscv-gnu-toolchain/configure --prefix="$ZTC_TOOLS_DIR" --enable-multilib
make $J linux


