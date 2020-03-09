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
../../riscv-gnu-toolchain/qemu/configure \
	--prefix="$ZTC_TOOLS_DIR" \
	--static --target-list="riscv32-linux-user riscv64-linux-user" \
	--disable-tools \
	--disable-docs \
	--disable-system 
make && make install

cd "$D/$WRKDIR2"
../../riscv-gnu-toolchain/qemu/configure \
	--prefix="$ZTC_TOOLS_DIR" \
	--target-list="riscv32-softmmu riscv64-softmmu" \
	--disable-tools \
	--disable-docs \
	--disable-werror 

# workaround ubuntu 18.04 bug
grep -v LIBSSH_CFLAGS config-host.mak >xx
mv xx config-host.mak

make && make install


