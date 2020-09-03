# SPDX-FileCopyrightText: 2020 Stefan Adams <stefan.adams@vipcomag.de>
# SPDX-License-Identifier: GPL-3.0-or-later

set -e
echo "building sel4test ..."

cd "$ZTOP/kernel"
D=`pwd`

SRCDIR="$D/sel4test"
WRKDIR="$D/sel4"
DTS="$SRCDIR/qemu.dts"

BBLDIR="$WRKDIR/build_${BITS}_bbl"

if [ "$1" == "clean" ]
then
	rm -rf "$BBLDIR" "$WRKDIR/build_${BITS}_sel4test"
	exit
fi

# build dependencies
build-toolchain.sh
build-cmake.sh
build-qemu.sh
build-board.sh --nobuild
build-sel4zsipos.sh 
build-initramfs.sh
build-linux.sh

# build sel4test
build-sel4-proj.sh sel4test qemu

# build bbl
mkdir -p "$BBLDIR"
cd "$BBLDIR"

if [ ! -f config.status ]
then
	"$D/riscv-pk/configure" \
		--host="riscv64-unknown-linux-gnu" \
		--with-arch=rv${BITS}imac \
		--with-mem-start=0x80000000 \
		--with-sel4-payload=../build_${BITS}_sel4test/elfloader/elfloader \
		--with-sel4-memsize=0x8000000 \
		--with-linux-payload=../../build_${BITS}/linux/vmlinux \
		--with-devicetree="$DTS" 
fi
make

echo
echo "sel4test build succesfully."




