set -e
echo "building distribution image ..."

cd "$ZTOP/scripts"

DESTDIR="$ZTOP/output"
OVERLAYDIR="$ZTOP/system/buildroot/overlays"

#./build-all.sh

rm -rf "$DESTDIR"
mkdir -p "$DESTDIR"

oldumask=`umask`
umask 0022

# copy fpga image
cp "$ZTOP/gateware/soc/build_$BOARD/gateware/top.bit" "$DESTDIR"

# copy app
export ZSIPOSOVL_INIT="$OVERLAYDIR/init_overlay"
export ZSIPOSOVL_APP="$OVERLAYDIR/app_overlay"
rm -rf "$ZSIPOSOVL_APP"
mkdir -p "$ZSIPOSOVL_APP/root" "$ZSIPOSOVL_APP/bin"
cp "$ZTOP/software/microwindows/src/bin/nxdisplay" "$ZSIPOSOVL_APP/bin"
cp -r "$ZTOP/software/zsipos" "$ZSIPOSOVL_APP/root"
cp -r "$ZTOP/software/fonts" "$ZSIPOSOVL_APP/root"
rm -rf "$ZSIPOSOVL_APP/root/zsipos/"*"/host"

# repack rootfs.tar
./build-buildroot.sh

cp "$ZTOP/system/buildroot/buildroot/output/images/rootfs.tar" "$DESTDIR"

cp "$ZTOP/kernel/build_$BITS/bbl/bbl.bin" "$DESTDIR"/boot.bin

umask $oldumask

