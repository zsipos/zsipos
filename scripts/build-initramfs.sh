# SPDX-FileCopyrightText: 2019 Stefan Adams <stefan.adams@vipcomag.de>
# SPDX-License-Identifier: GPL-3.0-or-later

set -e
echo "building initramfs ..."

if [ "$1"x == "clean"x ]
then
	m=clean
else
	m=
fi

cd "$ZTOP/kernel/initramfs"

make $m

