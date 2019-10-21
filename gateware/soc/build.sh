#nobuild="--no-compile-gateware --no-compile-software"
outdir=build_$BOARD
python3 $BOARD.py \
	--cpu-type=rocket${BITS} --cpu-variant=linux \
	--output-dir $outdir \
	--dts-file $outdir/software/include/generated/devicetree.dts \
 	--csr-json $outdir/$BOARD.json \
	$nobuild

