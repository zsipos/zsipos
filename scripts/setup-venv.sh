VDIR="$ZTOP/venv-zsipos"
if [ -d "$VDIR" ]
then
	. "$VDIR/bin/activate"
else
	python3 -m venv "$VDIR"
	. "$VDIR/bin/activate"
	pushd "$ZTOP/gateware"
	for i in migen litex litedram liteeth
	do
		pushd $i
		python3 setup.py develop
		popd
	done
	popd
fi


