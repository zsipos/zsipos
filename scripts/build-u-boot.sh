# SPDX-FileCopyrightText: 2019 Stefan Adams <stefan.adams@vipcomag.de>
# SPDX-License-Identifier: GPL-3.0-or-later

set -e
echo "building u-boot ..."

cd "$ZTOP/kernel"
D=`pwd`

SRCDIR="`pwd`/u-boot"
WRKDIR="`pwd`/build_$BITS/u-boot"

build-dts.sh $1

if [ "$1" == "clean" ]
then
	rm -rf "$WRKDIR" 
	exit
fi

mkdir -p "$WRKDIR"

cd "$SRCDIR"

if [ ! -f "$WRKDIR"/.config ]
then
	echo configure u-boot ...
	make O="$WRKDIR" vipcom_zsipos_defconfig
fi

make O="$WRKDIR"

cd "$WRKDIR"

if [ ! -f image.make ]
then
	cat - >image.make <<EOF
sel4+linux: ../bbl/bbl.bin.gz
	mkimage -A riscv -T kernel -C gzip -a 0x80000000 -e 0x80000000 -d \$? \$@

../bbl/bbl.bin.gz: ../bbl/bbl.bin
	gzip -f -k \$?
EOF
fi

make -f image.make

S="$ZTOP/kernel/build_$BITS/u-boot/u-boot.bin"
D=/tftpboot/boot.bin
if [ x"$1" != x"clean" ] && [ -d /tftpboot ] && [ -w $D ]
then
	cp "$S" "$D"
	echo "$S installed to $D"
fi






