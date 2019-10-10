#nobuild="--no-compile-gateware --no-compile-software"
outdir=build_$BOARD
python3 $BOARD.py \
	--output-dir $outdir \
 	--csr-json $outdir/$BOARD.json \
	$nobuild

