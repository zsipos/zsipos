set -e
echo "building fltk ..."

cd "$ZTOP/software"

build_for_processor() 
{
	BUILDDIR=`pwd`/build_$1
	if [ x"$2" == x"clean" ]
	then
		make clean
		rm -rf "$BUILDDIR"
		return
	fi
	if [ x"$1" == x"zsipos" ]
	then
		HOST="--host=$TC_PREFIX"
		X_INCLUDES="--x-include=\"$ZTOP/software/microwindows/src/nxlib\""
		X_LIBRARIES="--x-libraries=\"$ZTOP/software/microwindows/src/lib\""
	else
		unset HOST
		unset X_INCLUDES
		unset X_LIBRARIES
	fi
	export X_EXTRA_LIBS="-lfreetype"
	export CFLAGS="-fpic"
	export CXXFLAGS="$CFLAGS"
	pushd fltk
	[ -f ./configure ] || ./autogen.sh
	./configure \
		CFLAGS="-fpic" \
		CXXFLAGS="-fpic" \
		$HOST \
		$X_INCLUDES \
		$X_LIBRARIES \
		--enable-debug \
		--disable-xft \
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

