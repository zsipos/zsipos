# SPDX-FileCopyrightText: 2019 Stefan Adams <stefan.adams@vipcomag.de>
# SPDX-License-Identifier: GPL-3.0-or-later

set -e
echo "building zsipos application ..."

gitstamps.sh

build-sel4iptool.sh $1

if [ "$1"x == "clean"x ]
then
	m=clean
	exit
else
	m=
fi


(cd "$ZTOP/software/zsipos/gui"; make $m)
(cd "$ZTOP/software/zsipos/rtp"; make $m)

