# SPDX-FileCopyrightText: 2020 Stefan Adams <stefan.adams@vipcomag.de>
# SPDX-License-Identifier: GPL-3.0-or-later

set -e
echo "building sel4zsipos ..."

cd "$ZTOP/kernel"
D=`pwd`

WRKDIR="$D/sel4"

build-dts.sh $1

if [ "$1" == "clean" ]
then
	rm -rf "$WRKDIR/build_${BITS}_sel4zsipos"
	exit
fi

build-sel4-proj.sh sel4zsipos zsipos

