set -e
echo "buildind qemu .."

cd "$ZTOP/toolchain"
D=`pwd`

WRKDIR1=build/qemu_user
WRKDIR2=build/qemu_system

if [ "$1" == "clean" ]
then
	rm -rf "$WRKDIR1" "$WRKDIR2"
	exit 0
fi

export PATH="$ZTC_TOOLS_DIR/bin:$PATH"

mkdir -p "$WRKDIR1" "$WRKDIR2"

cd "$D/$WRKDIR1"
if [ ! -f .configured ]
then
	../../riscv-gnu-toolchain/qemu/configure \
		--prefix="$ZTC_TOOLS_DIR" \
		--static --target-list="riscv32-linux-user riscv64-linux-user" \
		--disable-tools \
		--disable-docs \
		--disable-system 
	touch .configured
fi
if [ ! -f .installed ]
then
	make $J
	make install
	touch .installed
fi

cd "$D/$WRKDIR2"
if [ ! -f .configured ]
then
	../../riscv-gnu-toolchain/qemu/configure \
		--prefix="$ZTC_TOOLS_DIR" \
		--target-list="riscv32-softmmu riscv64-softmmu" \
		--disable-tools \
		--disable-docs \
		--disable-werror 

	# workaround ubuntu 18.04 bug
	if grep -s "Ubuntu 18.04.4 LTS" /etc/os-release
	then
		grep -v LIBSSH_CFLAGS config-host.mak >xx
		mv xx config-host.mak
	fi
	touch .configured
fi
if [ ! -f .installed ]
then
	make $J
	make install
	touch .installed
fi



