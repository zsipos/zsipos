# SPDX-FileCopyrightText: 2019 Stefan Adams <stefan.adams@vipcomag.de>
# SPDX-License-Identifier: GPL-3.0-or-later

# add script directory to PATH
export PATH="$ZTOP/scripts:$PATH"

# vivado
. /opt/Xilinx/Vivado/2018.3/settings64.sh
unset LD_LIBRARY_PATH

#
# config choices
#

# 32bit or 64bit
export BITS=64

# which board to build
export BOARD="zsipos"

# cpu-type
export CPU_TYPE=rocket$BITS
export CPU_VARIANT=linux+dualcore

export ZTC_TYPE="buildroot" # "native"

# use gcc hardening flags
FORTIFY=1

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
	export ZTC_SYSROOT="$ZTC_ROOT/usr/riscv64-buildroot-linux-musl/sysroot"
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
export PATH="$ZTC_TOOLS_DIR/bin:$PATH"

export RISCV="$ZTC_ROOT"
export PATH="$PATH:$RISCV/bin"
export CROSS_COMPILE="$ZTC_PREFIX-"

export TC_DBGFLAGS=-g

if [ "$FORTIFY" == "1" ]
then
	export CFLAGS_HARDENING_ZSIPOS="-fstack-protector-all -fstack-clash-protection -D_FORTIFY_SOURCE=2"
	export LDFLAGS_HARDENING_ZSIPOS="-Wl,-z,noexecstack -Wl,-z,relro,-z,now"
	export CFLAGS_HARDENING_HOST="-fstack-protector-all -D_FORTIFY_SOURCE=2"
	export LDFLAGS_HARDENING_HOST="-Wl,-z,noexecstack -Wl,-z,relro,-z,now"
else
	export CFLAGS_HARDENING_ZSIPOS=""
	export LDFLAGS_HARDENING_ZSIPOS=""
	export CFLAGS_HARDENING_HOST=""
	export LDFLAGS_HARDENING_HOST=""
fi

#
# misc
#

export HOST_PYTHON_VERSION=`python -V | cut -d' ' -f2 | cut -d'.' -f1,2`

# do not touch rocket-chip
export ROCKET_IS_SUBMODULE=true

