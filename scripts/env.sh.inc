# add script directory to PATH
export PATH="$TOP/scripts:$PATH"

# add toolchain to PATH
export RISCV="$TOP/toolchain/riscv64"
export PATH="$RISCV/bin:$PATH"

# cross compile
export CROSS_COMPILE="riscv64-unknown-linux-gnu-"

# 32bit or 64bit
export BITS=64

# which board to build
export BOARD="nexys4ddr"


# do not rouch rocket-chip
export ROCKET_IS_SUBMODULE=true

