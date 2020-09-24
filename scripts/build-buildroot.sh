# SPDX-FileCopyrightText: 2019 Stefan Adams <stefan.adams@vipcomag.de>
# SPDX-License-Identifier: GPL-3.0-or-later

set -e
echo "building buildroot ..."

cd "$ZTOP/system/buildroot/buildroot"

if [ "$1"x == "clean"x ]
then
	rm -rf output
	exit
fi

if [ ! -f .config ]
then
	cp ../config .config
fi

if [ "$1"x == "config"x ]
then
	make menuconfig
	{
		echo "# SP""DX-FileCopyrightText: 2020 Stefan Adams <stefan.adams@vipcomag.de>"
		echo "# SP""DX-License-Identifier: CC0-1.0"
		echo
		cat .config
	} >../config
else
	make
fi

