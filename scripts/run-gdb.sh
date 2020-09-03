# SPDX-FileCopyrightText: 2019 Stefan Adams <stefan.adams@vipcomag.de>
# SPDX-License-Identifier: GPL-3.0-or-later

"$ZTC_GDB" -iex "set sysroot $ZTC_SYSROOT" -iex "set solib-search-path $ZTOP/software/zsipos/rtp/zsipos:$ZTOP/software/zsipos/gui/zsipos" $*

