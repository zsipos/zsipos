set -e
echo "building pjproject ..."

cd "$ZTOP/software/pjproject"

CFGCOMMON="\
--enable-epoll \
--disable-floating-point \
--disable-shared \
--disable-resample \
--disable-sound \
--disable-oss \
--disable-video \
--disable-sdl \
--disable-ffmpeg \
--disable-v4l2 \
--disable-openh264 \
--disable-silk \
--disable-opus \
--disable-bcg729 \
--disable-libyuv \
--disable-libwebrtc \
"

make_site_config()
{
	echo "#include <unistd.h>"
	echo "#define PJ_ICE_MAX_CAND 16"
	echo "#define PJ_ICE_MAX_CHECKS 256"
	echo "#define PJ_IOQUEUE_HAS_SAFE_UNREG	1"
	echo "#define PJ_IOQUEUE_DEFAULT_ALLOW_CONCURRENCY 1"
	echo "#define PJ_QOS_IMPLEMENTATION PJ_QOS_BSD"
	#echo "#ifdef __or1k__"
	#echo "#define PJ_LOCKFREE 1"
	#echo "#undef  PJ_HAS_FLOATING_POINT"
	#echo "#define PJ_HAS_FLOATING_POINT 0"
	#echo "#define PJ_ENABLE_EXTRA_CHECK 0"
	#echo "#undef pj_assert"
	#echo "#define pj_assert(expr) /**/"
	#echo "#endif"
} >pjlib/include/pj/config_site.h

build_for_processor() 
{
	CFG="$CFGCOMMON"
	if [ "$1" == "zsipos" ]
	then
		CFG+="--host=$ZTC_PREFIX"
	fi
	mv config.sub config.sub_bak
	cp "$ZTOP/scripts/config.sub" .
	export TARGET_NAME="$1"
	CFLAGS="-fpic $TC_DBGFLAGS" CXXFLAGS="-fpic $TC_DBGFLAGS" ./configure $CFG
	mv config.sub_bak config.sub
	make_site_config
	make
}

if [ "$1" == "clean" ]
then
	echo "cleaning in "`pwd`" ..."
	rm -rf */lib */bin */build/output
	rm -rf third_party/build/*/output third_party/lib
	rm -f build.mak
	rm -f build/cc-auto.mak
	rm -f build/os-auto.mak
	rm -f config.log
	rm -f config.status
	rm -f pjlib-util/build/os-auto.mak
	rm -f pjlib/build/os-auto.mak
	rm -f pjlib/include/pj/compat/m_auto.h
	rm -f pjlib/include/pj/compat/os_auto.h
	rm -f pjlib/include/pj/config_site.h
	rm -f pjmedia/build/os-auto.mak
	rm -f pjmedia/include/pjmedia-codec/config_auto.h
	rm -f pjmedia/include/pjmedia/config_auto.h
	rm -f pjsip/build/os-auto.mak
	rm -f pjsip/include/pjsip/sip_autoconf.h
	rm -f third_party/build/os-auto.mak
	exit 0
fi

build_for_processor zsipos
build_for_processor host

