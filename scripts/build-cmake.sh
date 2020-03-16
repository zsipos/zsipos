set -e
echo "buildind cmake .."

cd "$ZTOP/toolchain"
D=`pwd`

WRKDIR=build/CMake

if [ "$1" == "clean" ]
then
	rm -rf "$WRKDIR"
	exit 0
fi

export PATH="$ZTC_TOOLS_DIR/bin:$PATH"

mkdir -p "$WRKDIR" 

cd "$D/$WRKDIR"

if [ ! -f .configured ]
then
	../../CMake/configure --prefix=$ZTC_TOOLS_DIR
	touch .configured
fi

if [ ! -f .installed ]
then
	make $J
	make install
	touch .installed
fi

