#
# This is a small helper script for develpment.
# It adds the script directory and the toolchain directory to your path.
#

if [ ! -f scripts/env.sh.inc ]
then
	echo "please run this script from program root."
else
	export ZTOP=`pwd`
	. "$ZTOP/scripts/setup-venv.sh"
	. "$ZTOP/scripts/env.sh.inc"
	set +e
	export PATH="$ZTOP/scripts:$PATH"
fi
