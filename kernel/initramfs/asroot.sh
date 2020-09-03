# SPDX-FileCopyrightText: 2019 Stefan Adams <stefan.adams@vipcomag.de>
# SPDX-License-Identifier: GPL-3.0-or-later
cd $1
for i in dev bin sbin usr/bin usr/sbin
do
	mkdir -p $i
done
mknod dev/null c 1 3
mknod dev/tty c 5 0
mknod dev/zero c 1 5
mknod dev/console c 5 1
find . | cpio -H newc -o >$2

