set -e
echo "building sel4iptools ..."

(cd "$ZTOP/software/sel4iptool"; make $1)

