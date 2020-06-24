#./gateware/soc/cores/sdcard/verilog
cd "$ZTOP/./gateware/soc/cores/sdcard/verilog"
git checkout master

#./gateware/migen
cd "$ZTOP/./gateware/migen"
git checkout master

#./kernel/initramfs/busybox
cd "$ZTOP/./kernel/initramfs/busybox"
git checkout master

#./toolchain/riscv-gnu-toolchain
cd "$ZTOP/./toolchain/riscv-gnu-toolchain"
git checkout master

#./toolchain/riscv-openocd
cd "$ZTOP/./toolchain/riscv-openocd"
git checkout riscv

#./system/buildroot/buildroot
cd "$ZTOP/./system/buildroot/buildroot"
git checkout 2019.11.x

