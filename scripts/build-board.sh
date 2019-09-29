
echo "building board gateware .."

cd $TOP/gateware/soc

if [ "$1" == "clean" ]
then
	rm -rf build_*
	exit 0
fi

./build.sh

