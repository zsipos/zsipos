cd $1
for i in bin sbin usr/bin usr/sbin
do
	mkdir -p $i
done
mknod dev/null c 1 3
mknod dev/tty c 5 0
mknod dev/zero c 1 5
mknod dev/console c 5 1
mknod dev/mmcblk0 b 179 0
mknod dev/mmcblk0p1 b 179 1
find . | cpio -H newc -o >$2

