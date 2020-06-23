cd "$ZTOP"

ZSIPOS_URL="https://github.com/zsipos"

#TRUE
T=0
#FALSE
F=1

is_ignored()
{	
	git status "$1" 2>&1 >/dev/null || return $T
	case "$1" in
		".") return $T;;
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
	esac
	return $F
}

get_tag()
{
	cd "$ZTOP/$1"
	git status | grep "HEAD detached" | cut -d' ' -f4
}

is_taged()
{
	cd "$ZTOP/$1"
	tag=`get_tag $1`
	[ "$tag"x != x ] && [ "$tag"x == `git tag -l "$tag"`x ]
}

get_subprojects()
{
	for i in `find . -name .git | grep -v build_64`
	do
		p=`echo $i | sed 's/\/\.git$//g'`
		is_ignored "$p" || echo "$p"
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
	for i in `get_subprojects`
	do
		if is_zsipos "$i"
		then
			echo "$i"
		fi
	done
}

zsipos_list_detached()
{
	for i in `get_subprojects`
	do
		if is_zsipos "$i" && is_detached "$i"
		then
			is_taged "$i" || echo "$i" 
		fi
	done
}

zsipos_list_taged()
{
	for i in `get_subprojects`
	do
		if is_zsipos "$i" && is_taged "$i"
		then
			echo "$i "`get_tag "$i"`
		fi
	done
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
		list_zsipos
		;;
	"zsipos-list-detached")
		zsipos_list_detached
		;;
	"zsipos-list-taged")
		zsipos_list_taged
		;;
	*)
		echo "Usage: $0 option"
		exit 1
		;;
esac



