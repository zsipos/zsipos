# SPDX-FileCopyrightText: 2019 Stefan Adams <stefan.adams@vipcomag.de>
# SPDX-License-Identifier: GPL-3.0-or-later

VERSION=1
VDIR="$ZTOP/.venv-zsipos"

if [ -f "$VDIR/version" ]
then
	ENV_VERSION=`cat "$VDIR/version"`
else
	ENV_VERSION=0
fi

if [ "$ENV_VERSION" -lt "$VERSION" ]
then
	echo "python env version is $ENV_VERSION, needed version is $VERSION"
	echo "forcing python env rebuild ..."
	rm -rf "$VDIR"
fi

if [ -d "$VDIR" ]
then
	. "$VDIR/bin/activate"
else
	python3 -m venv "$VDIR"
	. "$VDIR/bin/activate"
	pip install --upgrade pip
	#zsipos
	pip install twisted==19.7
	pip install cython==0.29.14
	#litex
	pushd "$ZTOP/gateware"
	for i in migen litex litedram liteeth liteiclink
	do
		pushd $i
		python3 setup.py develop
		popd
	done
	popd
	#sel4
	pip install setuptools
	pip install sel4-deps
	pip install protobuf
	pip install camkes-deps
	echo $VERSION >"$VDIR/version"
fi


