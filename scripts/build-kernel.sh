# SPDX-FileCopyrightText: 2019 Stefan Adams <stefan.adams@vipcomag.de>
# SPDX-License-Identifier: GPL-3.0-or-later

set -e
echo "building kernel ..."

build-sel4zsipos.sh $1
build-initramfs.sh $1
build-linux.sh $1
build-bbl.sh $1

if [ x"$1" != x"clean" ] && [ -d /tftpboot ] && [ -w /tftpboot/boot.bin ]
then
	cp "$ZTOP/kernel/build_$BITS/bbl/bbl.bin" /tftpboot/boot.bin
	echo "bbl.bin installed to /tftpboot/boot.bin"
fi
