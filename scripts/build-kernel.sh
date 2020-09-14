# SPDX-FileCopyrightText: 2019 Stefan Adams <stefan.adams@vipcomag.de>
# SPDX-License-Identifier: GPL-3.0-or-later

set -e
echo "building kernel ..."

build-sel4zsipos.sh $1
build-initramfs.sh $1
build-linux.sh $1
build-bbl.sh $1
build-u-boot.sh $1

S="$ZTOP/kernel/build_$BITS/bbl/bbl.bin"
D=/tftpboot/boot.bin
if [ x"$1" != x"clean" ] && [ -d /tftpboot ] && [ -w $D ]
then
	cp "$S" "$D"
	echo "$S installed to $D"
fi
