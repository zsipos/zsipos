set -e
echo "building sel4zsipos ..."

cd "$ZTOP/kernel"
D=`pwd`

WRKDIR="$D/sel4"

if [ "$1" == "clean" ]
then
	rm -rf "$WRKDIR/build_${BITS}_sel4zsipos"
	exit
fi

build-sel4-proj.sh sel4zsipos zsipos

