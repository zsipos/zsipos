# add script directory to PATH
export PATH="$TOP/scripts:$PATH"

# add toolchain to PATH
export RISCV="$TOP/toolchain/riscv64"
export PATH="$RISCV/bin:$PATH"

# cross compile
export CROSS_COMPILE="riscv64-unknown-linux-gnu-"

# which board to build
export BOARD="nexys4ddr"



