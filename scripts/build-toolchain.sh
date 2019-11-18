set -e
echo "building riscv toolchain .."

cd "$ZTOP/toolchain"

if [ "$1" == "clean" ]
then
	rm -rf riscv64 build
	exit 0
fi

mkdir -p build
cd build
../riscv-gnu-toolchain/configure --prefix="$RISCV" --enable-multilib
make $J linux newlib


