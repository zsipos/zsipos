# SPDX-FileCopyrightText: 2019 Stefan Adams <stefan.adams@vipcomag.de>
# SPDX-License-Identifier: GPL-3.0-or-later

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
	../../riscv-openocd/configure --prefix="$ZTC_TOOLS_DIR" 
fi
make $J
make install
popd
cp misc/openocd_xilinx.cfg "$ZTC_TOOLS_DIR/share/openocd"
pushd "$ZTC_TOOLS_DIR/share/openocd"
if [ ! -d bscan_spi_bitstreams ]
then
	git clone https://github.com/quartiq/bscan_spi_bitstreams
fi
popd


