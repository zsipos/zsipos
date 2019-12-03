set -e
echo "building zsipos application ..."

gitstamps.sh

(cd "$ZTOP/software/zsipos/gui"; make $1)
(cd "$ZTOP/software/zsipos/rtp"; make $1)

