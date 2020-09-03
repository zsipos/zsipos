# SPDX-FileCopyrightText: 2020 Stefan Adams <stefan.adams@vipcomag.de>
# SPDX-License-Identifier: GPL-3.0-or-later

cd "$ZTOP"

ZSIPOS_URL="https://github.com/zsipos"
ZSIPOS_BRANCHNAMES="$ZTOP/scripts/checkout-zsipos-branchnames.sh"
OTHER_BRANCHNAMES="$ZTOP/scripts/checkout-other-branchnames.sh"
TMPFILE="/tmp/diff-tmp"

#TRUE
T=0
#FALSE
F=1

get_tag()
{
	cd "$ZTOP/$1"
	git status | grep "HEAD detached" | cut -d' ' -f4
}

get_branch()
{
	cd "$ZTOP/$1"
	git status | grep "On branch" | cut -d' ' -f3
}

is_ignored()
{	
	git status "$1" 2>&1 >/dev/null || return $T
	case "$1" in
		".") return $T;;
		"./toolchain/riscv64/share/openocd/bscan_spi_bitstreams") return $T;;
	esac
	return $F
}

is_detached()
{
	cd "$ZTOP/$1"
	git status | grep -q "HEAD"
}

is_zsipos()
{
	cd "$ZTOP/$1"
	case `git remote get-url origin` in 
		"$ZSIPOS_URL"*) return $T;;
		"") return $T;;
	esac
	return $F
}

is_taged()
{
	cd "$ZTOP/$1"
	tag=`get_tag $1`
	[ "$tag"x != x ] && [ "$tag"x == `git tag -l "$tag"`x ]
}

is_ahead()
{
	cd "$ZTOP/$1"
	git status | grep -q "Your branch is ahead"
}

get_subprojects()
{
	cd "$ZTOP"
	for i in `find . -name .git | grep -v build_64`
	do
		p=`echo $i | sed 's/\/\.git$//g'`
		is_ignored "$p" || echo "$p"
	done
}

get_zsipos_subprojects()
{
	cd "$ZTOP"
	for i in `get_subprojects`
	do
		is_zsipos "$i" && echo "$i"
	done
}

list_subprojects()
{
	get_subprojects
}

list_detached()
{
	for i in `get_subprojects`
	do
		if is_detached "$i"
		then
			echo "$i"
		fi
	done
}

list_taged()
{
	for i in `get_subprojects`
	do
		if is_taged "$i"
		then
			echo "$i "`get_tag "$i"`
		fi
	done
}

zsipos_list()
{
	for i in `get_zsipos_subprojects`
	do
		echo "$i"
	done
}

zsipos_list_detached()
{
	for i in `get_zsipos_subprojects`
	do
		if is_detached "$i" && ! is_taged "$i"
		then
			echo "$i" 
		fi
	done
}

zsipos_list_taged()
{
	for i in `get_zsipos_subprojects`
	do
		if is_taged "$i"
		then
			echo "$i:"`get_tag "$i"`
		fi
	done
}

zsipos_list_branches()
{
	for i in `get_zsipos_subprojects`
	do
		if ! is_taged "$i"
		then
			echo "$i:"`get_branch "$i"`
		fi
	done
}

other_list_branches()
{
	for i in `get_subprojects`
	do
		if ! is_detached "$i" && ! is_zsipos "$i"
		then
			echo "$i:"`get_branch "$i"`
		fi
	done
}

spdx_header()
{
	echo "# SPDX-FileCopyrightText: 2020 Stefan Adams <stefan.adams@vipcomag.de>"
	echo "# SPDX-License-Identifier: GPL-3.0-or-later"
	echo
}

zsipos_save_branchnames()
{
	spdx_header
	for i in `get_zsipos_subprojects`
	do
		if ! is_taged "$i"
		then
			branchname=`get_branch "$i"`
		else
			branchname=`get_tag "$i"`
		fi
		echo "#$i"
		echo "cd \"\$ZTOP/$i\""
		echo "git checkout $branchname"
		echo
	done
}

other_save_branchnames()
{
	spdx_header
	echo
	echo "echo \"### only for cut+paste ###\""
	echo
	echo "exit 0"
	echo
	for i in `get_subprojects`
	do
		if ! is_detached "$i" && ! is_zsipos "$i"
		then
			branchname=`get_branch "$i"`
			echo "#$i"
			echo "cd \"\$ZTOP/$i\""
			echo "git checkout $branchname"
			echo
		fi
	done
}

zsipos_check()
{
	cd "$ZTOP"
	git status
	echo
	ok=$T
	for i in . `get_zsipos_subprojects`
	do
		cd "$ZTOP/$i"
		if is_detached "$i" && ! is_taged "$i"
		then
			echo "$i is detached"
			ok=$F
		fi
		if is_ahead "$i"
		then
			echo "$i has unpushed changes"
			ok=$F
		fi
		origin=`git remote get-url origin`
		if [ "$origin"x == x ]
		then
			echo "$i has no origin"
			ok=$F
		fi
	done
	zsipos_save_branchnames >"$TMPFILE"
	if ! cmp -s "$TMPFILE" "$ZSIPOS_BRANCHNAMES"
	then
		echo "zsipos branchnames have changed"
		mv "$TMPFILE" "$TMPFILE"-zsipos
		ok=$F
	fi
	other_save_branchnames >"$TMPFILE"
	if ! cmp -s "$TMPFILE" "$OTHER_BRANCHNAMES"
	then
		echo "warning: foreign branchnames have changed"
		mv "$TMPFILE" "$TMPFILE"-other
	fi
	rm -f "$TMPFILE"
	if [ $ok == $T ]
	then
		echo "Everything is fine!"
		return $T
	else
		echo
		echo "**CHECK HAD ERRORS!**"
		return $F
	fi
}

case "$1" in
	"list")
		list_subprojects
		;;
	"list-detached")
		list_detached
		;;
	"list-taged")
		list_taged
		;;
	"zsipos-list")
		zsipos_list
		;;
	"zsipos-list-detached")
		zsipos_list_detached
		;;
	"zsipos-list-taged")
		zsipos_list_taged
		;;
	"zsipos-list-branches")
		zsipos_list_branches
		;;
	"other-list-branches")
		other_list_branches
		;;
	"zsipos-save-branchnames")
		zsipos_save_branchnames >"$ZSIPOS_BRANCHNAMES"
		chmod +x "$ZSIPOS_BRANCHNAMES"
		;;
	"other-save-branchnames")
		other_save_branchnames >"$OTHER_BRANCHNAMES"
		chmod +x "$OTHER_BRANCHNAMES"
		;;
	"zsipos-check")
		zsipos_check
		;;
	*)
		echo "Usage: $0 option"
		exit 1
		;;
esac



