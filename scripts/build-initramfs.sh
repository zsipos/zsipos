set -e
echo "building initramfs ..."

cd "$ZTOP/kernel/initramfs"
make $1
