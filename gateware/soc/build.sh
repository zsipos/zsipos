# SPDX-FileCopyrightText: 2019 Stefan Adams <stefan.adams@vipcomag.de>
# SPDX-License-Identifier: GPL-3.0-or-later

if [ "$1" == "--nobuild" ]
then
  nobuild="true"
  shift
fi
if [ "$nobuild" == "true" ]
then
	nobuild="--no-compile-gateware --no-compile-software"
fi
outdir=build_$BOARD
python3 $BOARD.py \
	--cpu-type=$CPU_TYPE --cpu-variant=$CPU_VARIANT \
	--l2-size=0 \
	--integrated-sram-size=16384 \
	--csr-address-width=16 \
	--csr-paging=4096 \
	--output-dir $outdir \
	--dts-file $outdir/software/include/generated/devicetree.dts \
	--csr-offset-file $outdir/software/include/generated/csroffsets.h \
 	--csr-json $outdir/$BOARD.json \
	$nobuild $*

