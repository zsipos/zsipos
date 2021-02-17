# SPDX-FileCopyrightText: 2020 Stefan Adams <stefan.adams@vipcomag.de>
# SPDX-License-Identifier: GPL-3.0-or-later

#./gateware/liteeth
cd "$ZTOP/./gateware/liteeth"
git checkout master-zsipos

#./gateware/soc/cores/aes/verilog
cd "$ZTOP/./gateware/soc/cores/aes/verilog"
git checkout master

#./gateware/soc/cores/sha1/verilog
cd "$ZTOP/./gateware/soc/cores/sha1/verilog"
git checkout master-zsipos

#./gateware/liteiclink
cd "$ZTOP/./gateware/liteiclink"
git checkout master

#./gateware/litedram
cd "$ZTOP/./gateware/litedram"
git checkout master-zsipos

#./gateware/litex
cd "$ZTOP/./gateware/litex"
git checkout master-zsipos

#./gateware/litex/litex/soc/cores/cpu/rocket2/verilog
cd "$ZTOP/./gateware/litex/litex/soc/cores/cpu/rocket2/verilog"
git checkout master

#./software/microwindows
cd "$ZTOP/./software/microwindows"
git checkout master-zsipos

#./software/fltk
cd "$ZTOP/./software/fltk"
git checkout master-zsipos

#./software/zrtpcpp
cd "$ZTOP/./software/zrtpcpp"
git checkout master-zsipos

#./kernel/sel4/tools/seL4
cd "$ZTOP/./kernel/sel4/tools/seL4"
git checkout master-zsipos

#./kernel/sel4/projects/util_libs
cd "$ZTOP/./kernel/sel4/projects/util_libs"
git checkout master-zsipos

#./kernel/sel4/projects/libpicotcpng/picotcp
cd "$ZTOP/./kernel/sel4/projects/libpicotcpng/picotcp"
git checkout master-zsipos

#./kernel/sel4/kernel
cd "$ZTOP/./kernel/sel4/kernel"
git checkout master-zsipos

#./kernel/sel4/toplevels/sel4test
cd "$ZTOP/./kernel/sel4/toplevels/sel4test"
git checkout master-zsipos

#./kernel/linux
cd "$ZTOP/./kernel/linux"
git checkout linux-4.19.y-zsipos-sel4

#./kernel/u-boot
cd "$ZTOP/./kernel/u-boot"
git checkout master-zsipos

#./kernel/riscv-pk
cd "$ZTOP/./kernel/riscv-pk"
git checkout zsipos-sel4

