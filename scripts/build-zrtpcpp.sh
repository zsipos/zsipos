# SPDX-FileCopyrightText: 2019 Stefan Adams <stefan.adams@vipcomag.de>
# SPDX-License-Identifier: GPL-3.0-or-later

set -e
echo "building zrtpcpp ..."

create_zsipos_cmake_toolchain()
{
# this one is important
echo "SET(CMAKE_SYSTEM_NAME Linux)"
# this one not so much
echo "SET(CMAKE_SYSTEM_VERSION 1)"

# specify the cross compiler
echo "SET(CMAKE_C_COMPILER   $ZTC_CC)"
echo "SET(CMAKE_CXX_COMPILER $ZTC_CXX)"
echo "SET(CMAKE_AR $ZTC_AR)"
echo "SET(PKG_CONFIG_EXECUTABLE $ZTC_ROOT/bin/pkg-config)"

# where is the target environment
echo "SET(CMAKE_FIND_ROOT_PATH  $ZTC_BUILDROOT)"

# search for programs in the build host directories
echo "SET(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)"
# for libraries and headers in the target directories
echo "SET(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)"
echo "SET(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)"
}

build_for_processor()
{
	echo building for $1
	cd "$ZTOP/software"
	BUILDDIR=`pwd`/build_$1/zrtpcpp
	mkdir -p "$BUILDDIR"
	cd "$BUILDDIR"
	CFLAGS="-fpic -pthread"
	CXXFLAGS="$CFLAGS"
	CMAKEOPTS="-DCORE_LIB=ON -DBUILD_STATIC=ON -DBUILD_SHARED=OFF -DSDES=true"
	if [ "$1" == "zsipos" ]
	then
		create_zsipos_cmake_toolchain >cmake.toolchain
		CMAKEOPTS+=" -DCMAKE_TOOLCHAIN_FILE=cmake.toolchain -DCRYPTO_STANDALONE=true"
		ADD=" -DZSIPOS_HW_AES -DZSIPOS_HW_SHA1"
		CFLAGS+="$ADD"
		CXXFLAGS+="$ADD"
	fi
	cmake $CMAKEOPTS -DCMAKE_C_FLAGS="$CFLAGS" -DCMAKE_CXX_FLAGS="$CXXFLAGS" ../../zrtpcpp
#	if [ "$1" == "zsipos" ]
#	then
#		echo fix cmake bug ..
#		f=clients/no_client/CMakeFiles/zrtpcppcore.dir/link.txt
#		mv $f $f.bak
#		echo -n "$ZTC_AR" >$f
#		sed 's/\"\"//g' <$f.bak >>$f
#		rm $f.bak
#	fi
	make VERBOSE=1
}

clean_for_processor()
{
	cd "$ZTOP/software"
	rm -rf "build_$1/zrtpcpp"
}

if [ "$1" == "clean" ]
then
	clean_for_processor zsipos
	clean_for_processor host
else
	build_for_processor zsipos
	build_for_processor host
fi

