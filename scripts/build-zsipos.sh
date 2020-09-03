# SPDX-FileCopyrightText: 2019 Stefan Adams <stefan.adams@vipcomag.de>
# SPDX-License-Identifier: GPL-3.0-or-later

set -e
echo "building zsipos application ..."

gitstamps.sh

build-sel4iptool.sh $1
(cd "$ZTOP/software/zsipos/gui"; make $1)
(cd "$ZTOP/software/zsipos/rtp"; make $1)

