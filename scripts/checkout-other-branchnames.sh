
echo "### only for cut+paste ###"

exit 0

#./gateware/soc/cores/sdcard/verilog
cd "$ZTOP/./gateware/soc/cores/sdcard/verilog"
git checkout master

#./gateware/migen
cd "$ZTOP/./gateware/migen"
git checkout master

#./kernel/sel4/tools/nanopb
cd "$ZTOP/./kernel/sel4/tools/nanopb"
git checkout master

#./kernel/sel4/tools/camkes-tool
cd "$ZTOP/./kernel/sel4/tools/camkes-tool"
git checkout master

#./kernel/sel4/tools/capdl
cd "$ZTOP/./kernel/sel4/tools/capdl"
git checkout master

#./kernel/sel4/tools/riscv-pk
cd "$ZTOP/./kernel/sel4/tools/riscv-pk"
git checkout master

#./kernel/sel4/projects/picotcp
cd "$ZTOP/./kernel/sel4/projects/picotcp"
git checkout master

#./kernel/sel4/projects/projects_libs
cd "$ZTOP/./kernel/sel4/projects/projects_libs"
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

