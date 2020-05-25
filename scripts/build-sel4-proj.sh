set -e
echo "build sel4 project $1 ..."

cd "$ZTOP/kernel/sel4"
D=`pwd`

if [ "$1$2"x == x ]
then
	echo "usage: $0 <project-name> <qemu|zsipos|clean>"
	exit 1
fi

DSTDIR="$D/build_${BITS}_$1"
SRCDIR="$D/toplevels/$1"
CACHE_DIR="$DSTDIR/.sel4_cache"

case "$2" in
	clean)
		rm -rf "$DSTDIR"
		exit 0
	;;
	qemu)
		SEL4OPTS="-DPLATFORM=qemu-zsipos -DRISCV64=TRUE -DSIMULATION=TRUE"
	;;
	zsipos)
		SEL4OPTS="-DPLATFORM=hw-zsipos -DRISCV64=TRUE -DSIMULATION=TRUE"
	;;
	pc99)
		SEL4OPTS="-DPLATFORM=pc99 -DSIMULATION=TRUE"
	;;
esac

if [ ! -f "$DSTDIR/.initdone" ]
then
	rm -rf "$DSTDIR"
	mkdir -p "$DSTDIR"
	cd "$DSTDIR"
	cmake -G Ninja $SEL4OPTS -DSEL4_CACHE_DIR="$CACHE_DIR" -C "$SRCDIR/settings.cmake" "$SRCDIR"	
	touch .initdone
fi

cd "$DSTDIR"
ninja



