BS=1024
COUNT=10240

mkdir /mnt
mount /dev/mmcblk0p1 /mnt
rm /mnt/yy
time dd if=/dev/zero of=/mnt/yy bs=$BS count=$COUNT conv=fsync
umount /mnt
mount /dev/mmcblk0p1 /mnt
time dd if=/mnt/yy of=/dev/null bs=$BS count=$COUNT
umount /mnt
