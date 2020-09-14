# SPDX-FileCopyrightText: 2020 Stefan Adams <stefan.adams@vipcomag.de>
# SPDX-License-Identifier: GPL-3.0-or-later

set -e
echo "building sel4iptools ..."

cd "$ZTOP/software/sel4iptool"

if [ "$1"x == "clean"x ]
then
	m=clean
else
	m=
fi

make $m


