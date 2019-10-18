#nobuild="--no-compile-gateware --no-compile-software"
outdir=build_$BOARD
python3 $BOARD.py \
	--cpu-type=rocket64 --cpu-variant=linux \
	--output-dir $outdir \
 	--csr-json $outdir/$BOARD.json \
	$nobuild

