# SPDX-FileCopyrightText: 2019 Stefan Adams <stefan.adams@vipcomag.de>
# SPDX-License-Identifier: GPL-3.0-or-later

set -e
echo "building distribution image ..."

cd "$ZTOP/scripts"

DESTDIR="$ZTOP/output"
OVERLAYDIR="$ZTOP/system/buildroot/overlays"

if [ x"$1" == x"rebuild" ]
then
	build-all.sh clean
	build-all.sh
else
	build-zsipos.sh
fi

rm -rf "$DESTDIR"
mkdir -p "$DESTDIR"

oldumask=`umask`
umask 0022

# build fpga flash image with bootrom
build-board.sh --nobuild --buildrom

# copy fpga image
cp "$ZTOP/gateware/soc/build_$BOARD/gateware/top.bit" "$DESTDIR"
cp "$ZTOP/gateware/soc/build_$BOARD/gateware/top.bin" "$DESTDIR"/fpga-netboot.bin
cp "$ZTOP/gateware/soc/build_$BOARD/gateware/rom.mcs" "$DESTDIR"/fpga-romboot.mcs

if false 
then

# copy sshtest only
echo "copy sshtest ..."
export ZSIPOSOVL_INIT="$ZTOP/system/buildroot/overlays/sshtest_overlay"
unset  ZSIPOSOVL_APP
INIT_DIR="$ZTOP/system/buildroot/buildroot/output/target/etc/init.d"
rm -f "$INIT_DIR/S30display"
rm -f "$INIT_DIR/S30zsiposconf"
rm -f "$INIT_DIR/S49chrony"
rm -f "$INIT_DIR/S49zsiposconf2"
rm -f "$INIT_DIR/S99zsiposapp"

else

# copy app
echo "copy zsipos app ..."
export ZSIPOSOVL_INIT="$OVERLAYDIR/init_overlay"
export ZSIPOSOVL_APP="$OVERLAYDIR/app_overlay"
rm -rf "$ZSIPOSOVL_APP"
mkdir -p "$ZSIPOSOVL_APP/root" "$ZSIPOSOVL_APP/bin"
cp "$ZTOP/software/microwindows/src/bin/nxdisplay" "$ZSIPOSOVL_APP/bin"
cp "$ZTOP/software/sel4iptool/sel4iptool" "$ZSIPOSOVL_APP/bin"
cp -r "$ZTOP/software/zsipos" "$ZSIPOSOVL_APP/root"
cp -r "$ZTOP/software/fonts" "$ZSIPOSOVL_APP/root"
rm -rf "$ZSIPOSOVL_APP/root/zsipos/"*"/host"

fi

# repack rootfs.tar
./build-buildroot.sh

cp "$ZTOP/system/buildroot/buildroot/output/images/rootfs.tar" "$DESTDIR"

cp "$ZTOP/kernel/build_$BITS/bbl/bbl.bin" "$DESTDIR"/boot.bin

umask $oldumask

