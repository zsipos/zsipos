set -e
echo "building riscv-openocd .."

cd "$ZTOP/toolchain"

if [ "$1" == "clean" ]
then
	rm -rf build/openocd
	exit 0
fi

pushd riscv-openocd
if [ ! -f configure ]
then
	./bootstrap
fi
popd
mkdir -p build/openocd
pushd build/openocd
if [ ! -f config.status ]
then
	../../riscv-openocd/configure --prefix="$RISCV" 
fi
make $J
make install
popd
cp misc/openocd_xilinx.cfg "$RISCV/share/openocd"
pushd "$RISCV/share/openocd"
if [ ! -d bscan_spi_bitstreams ]
then
	git clone https://github.com/quartiq/bscan_spi_bitstreams
fi
popd


