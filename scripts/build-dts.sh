set -e
echo "building dts ..."

cd "$ZTOP/kernel/dts"

make $1

