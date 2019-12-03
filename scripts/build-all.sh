set -e
echo "build ALL ..."

for i in buildroot toolchain openocd qemu board kernel microwindows fltk pj zrtpcpp zsipos
do
	build-$i.sh $1
done
