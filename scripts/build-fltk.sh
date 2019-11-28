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
	else
		unset LIBS
		unset HOST
		unset X_INCLUDES
		unset X_LIBRARIES
		export X_EXTRA_LIBS="-lfreetype"
	fi
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

