# add script directory to PATH
export PATH="$ZTOP/scripts:$PATH"

#
# config choices
#

# 32bit or 64bit
export BITS=64

# which board to build
export BOARD="zsipos"

# cpu-type
export CPU_TYPE=rocket$BITS
export CPU_VARIANT=linux

export ZTC_TYPE="buildroot" # "native"

#
# end of config choices
#

#
# toolchain section
#

if [ "$ZTC_TYPE" == "buildroot" ]
then
	export ZTC_BUILDROOT="$ZTOP/system/buildroot/buildroot"
	export ZTC_ROOT="$ZTC_BUILDROOT/output/host"
	export ZTC_PREFIX="riscv64-linux"
	export ZTC_SYSROOT="$ZTC_ROOT/usr/riscv64-buildroot-linux-gnu/sysroot"
	for i in addr2line ar as c++ c++.br_real cc cc.br_real c++filt cpp cpp.br_real\
                           elfedit g++ g++.br_real gcc gcc.br_real gcov gprof ld ld.bfd\
                           nm objcopy objdump ranlib readelf size strings strip
	do
		ln -sf $ZTC_ROOT/bin/$ZTC_PREFIX-$i $ZTC_ROOT/bin/riscv64-unknown-linux-gnu-$i
	done
else
	export ZTC_ROOT="$ZTOP/toolchain/riscv64"
	export ZTC_PREFIX="riscv64-unknown-linux-gnu"
	export ZTC_SYSROOT="$ZTC_ROOT/sysroot"
fi

export ZTC_CC="$ZTC_PREFIX-gcc"
export ZTC_CXX="$ZTC_PREFIX-g++"
export ZTC_LD="$ZTC_PREFIX-ld"
export ZTC_AR="$ZTC_PREFIX-ar"
export ZTC_OBJCOPY="$ZTC_PREFIX-objcopy"
export ZTC_GDB="riscv64-unknown-linux-gnu-gdb"

export ZTC_TOOLS_DIR="$ZTOP/toolchain/riscv64"
export PATH="$PATH:$ZTC_TOOLS_DIR/bin"

export RISCV="$ZTC_ROOT"
export PATH="$PATH:$RISCV/bin"
export CROSS_COMPILE="$ZTC_PREFIX-"

export TC_DBGFLAGS=-g

#
# misc
#

export HOST_PYTHON_VERSION=`python -V | cut -d' ' -f2 | cut -d'.' -f1,2`

# do not touch rocket-chip
export ROCKET_IS_SUBMODULE=true

