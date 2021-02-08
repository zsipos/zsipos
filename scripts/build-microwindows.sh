# SPDX-FileCopyrightText: 2019 Stefan Adams <stefan.adams@vipcomag.de>
# SPDX-License-Identifier: GPL-3.0-or-later
set -e

build_for_processor() 
{
	echo "building microwindows ..."
	cd "$ZTOP/software/microwindows/src"
	export CONFIG="`pwd`/Configs/config.zsipos"
	if [ x"$2" == x"clean" ]
	then
		m=clean
	else
		m=
	fi
	make -k $m VERBOSE=y CONFIG=$CONFIG CFLAGS="-fpic $CFLAGS_HARDENING_ZSIPOS $LDFLAGS_HARDENING_ZSIPOS"
	cd lib
	rm -f libX11.a
	ln -s `pwd`/libNX11.a libX11.a
}

build_for_processor riscv $1 

