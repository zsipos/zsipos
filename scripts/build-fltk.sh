# SPDX-FileCopyrightText: 2019 Stefan Adams <stefan.adams@vipcomag.de>
# SPDX-License-Identifier: GPL-3.0-or-later

set -e
echo "building fltk ..."

cd "$ZTOP/software"

build_for_processor() 
{
	BUILDDIR=`pwd`/build_$1/fltk
	if [ x"$2" == x"clean" ]
	then
		(cd fltk; make clean)
		rm -rf "$BUILDDIR"
		return
	fi
	if [ x"$1" == x"zsipos" ]
	then
		export HOST="--host=$ZTC_PREFIX"
		export X_INCLUDES="--x-include=\"$ZTOP/software/microwindows/src/include\""
		export X_LIBRARIES="--x-libraries=\"$ZTOP/software/microwindows/src/lib\""
		export X_EXTRA_LIBS="-lnano-X -lfreetype -lts -lz"
		export XFT="disable"
		export HARDENING="$CFLAGS_HARDENING_ZSIPOS $LDFLAGS_HARDENING_ZSIPOS"
	else
		unset LIBS
		unset HOST
		unset X_INCLUDES
		unset X_LIBRARIES
		unset HARDENING
		export X_EXTRA_LIBS="-lfreetype"
		export XFT="enable"
		export HARDENING="$CFLAGS_HARDENING_HOST $LDFLAGS_HARDENING_HOST"
	fi
	export CFLAGS="-fpic $HARDENING"
	export CXXFLAGS="$CFLAGS"
	pushd fltk
	[ -f ./configure ] || ./autogen.sh
	./configure \
		$HOST \
		$X_INCLUDES \
		$X_LIBRARIES \
		--enable-debug \
		--$XFT-xft \
		--disable-xfixes \
		--disable-xrender \
		--disable-xcursor \
		--disable-xinerama \
		--disable-xdbe \
		--disable-gl \
		--prefix="$BUILDDIR"
	make clean
	make
	make install
	popd
}

build_for_processor zsipos $1 
build_for_processor host   $1 

