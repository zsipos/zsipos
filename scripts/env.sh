#
# This is a small helper script for develpment.
# It adds the script directory and the toolchain directory to your path.
#

if [ ! -f scripts/env.sh.inc ]
then
	echo "please run this script from program root."
else
	export TOP=`pwd`
	. "$TOP/scripts/env.sh.inc"

	set +e

	export PATH="$TOP/scripts:$PATH"
fi
