set -e
echo "building sel4test ..."

cd "$ZTOP/kernel"
D=`pwd`

SRCDIR="$D/sel4test"
WRKDIR="$D/build_$BITS/sel4test"
DTS="$SRCDIR/qemu.dts"

if [ "$1" == "clean" ]
then
	rm -rf "$WRKDIR"
	exit
fi

# build dependencies
build-toolchain.sh
build-cmake.sh
build-qemu.sh
build-initramfs.sh
build-linux.sh

# get repo
REPO="$ZTC_TOOLS_DIR/bin/repo"
if [ ! -f "$REPO" ]
then
	curl https://storage.googleapis.com/git-repo-downloads/repo >"$REPO"
	chmod +x "$REPO"
fi

# build sel4-test
mkdir -p "$WRKDIR"
cd "$WRKDIR"
if [ ! -d .repo ]
then
	repo init -u https://github.com/seL4/sel4test-manifest.git
	repo sync
	patch -p1 <"$SRCDIR/zsipos-patches"
	mkdir build
	pushd build
		../init-build.sh -DPLATFORM=spike -DSIMULATION=TRUE -DRISCV64=TRUE
	popd
fi
cd "$WRKDIR/build"
ninja

# build bbl
mkdir -p "$WRKDIR/bbl"
cd "$WRKDIR/bbl"

if [ ! -f config.status ]
then
	"$D/riscv-pk/configure" \
		--host="riscv64-unknown-linux-gnu" \
		--with-arch=rv${BITS}imac \
		--with-mem-start=0x80000000 \
		--with-sel4-payload=../build/elfloader/elfloader \
		--with-sel4-memsize=0x8000000 \
		--with-linux-payload=../../linux/vmlinux \
		--with-devicetree="$DTS" 
fi
make

echo
echo "sel4test build succesfully."




