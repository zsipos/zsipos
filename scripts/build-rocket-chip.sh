
echo "building rocket-chip .."

cd $TOP/gateware/litex/litex/soc/cores/cpu/rocket2/verilog

if [ "$1" == "clean" ]
then
	rm -rf rocket-chip/vsim/generated-src/*
	exit 0
fi

./build.sh



