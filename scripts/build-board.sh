set -e
echo "building board gateware .."

cd "$ZTOP/gateware/soc"

if [ "$1" == "clean" ]
then
	rm -rf build_*
	exit
fi

./build.sh $*

rm -f vivado*.log vivado*.jou
