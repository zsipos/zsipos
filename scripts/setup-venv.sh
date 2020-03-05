VDIR="$ZTOP/.venv-zsipos"
if [ -d "$VDIR" ]
then
	. "$VDIR/bin/activate"
else
	python3 -m venv "$VDIR"
	. "$VDIR/bin/activate"
	pip install --upgrade pip
	pip install twisted==19.7
	pip install cython==0.29.14
	pushd "$ZTOP/gateware"
	for i in migen litex litedram liteeth liteiclink
	do
		pushd $i
		python3 setup.py develop
		popd
	done
	popd
fi


