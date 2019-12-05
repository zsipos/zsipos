cd $ZTOP

{
echo "gitversions = {"
echo "    'zsipos' : 0x"`git rev-parse --short HEAD`","

git submodule foreach git rev-parse --short HEAD | while read label
do
	label=`echo $label | cut -d"'" -f 2`
	read vers
	echo "    '$label' : 0x$vers,"
done
echo "}"

echo "gitdates = {"
echo "    'zsipos' : "`git log -1 --format=%ct`","

git submodule foreach git log -1 --format=%ct | while read label
do
	label=`echo $label | cut -d"'" -f 2`
	read tstamp
	echo "    '$label' : $tstamp,"
done
echo "}"

} >"$ZTOP/software/zsipos/gitversions.py" 

