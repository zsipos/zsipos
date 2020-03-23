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
if [ ! -f .configured ]
then
	../riscv-gnu-toolchain/configure --prefix="$ZTC_TOOLS_DIR" --enable-linux --with-arch=rv64imac --with-abi=lp64 # --enable-multilib 
	touch .configured
fi
make $J


