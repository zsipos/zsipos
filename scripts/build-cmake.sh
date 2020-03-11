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

if [ ! -f .configure ]
then
	../../CMake/configure --prefix=$ZTC_TOOLS_DIR
	touch .configure
fi

make
make install
