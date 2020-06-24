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

#./kernel/linux
cd "$ZTOP/./kernel/linux"
git checkout linux-4.19.y-zsipos

#./kernel/riscv-pk
cd "$ZTOP/./kernel/riscv-pk"
git checkout master-zsipos

