build_for_processor() 
{
	echo "building microwindows ..."
	cd "$ZTOP/software/microwindows/src"
	export CONFIG="`pwd`/Configs/config.zsipos"
	make -k $2 CONFIG=$CONFIG
	if [ x"$2" == x"clean" ]
	then
		return
	fi
	cd lib
	rm -f libX11.a
	ln -s `pwd`/libNX11.a libX11.a
}

build_for_processor riscv $1 

