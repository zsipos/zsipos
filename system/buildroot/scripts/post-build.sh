# SPDX-FileCopyrightText: 2019 Stefan Adams <stefan.adams@vipcomag.de>
# SPDX-License-Identifier: CC0-1.0
#
# This is a buildroot internal helper script.
#
DSTDIR="$1"

rm -f "$DSTDIR/etc/network/interfaces"
rm -f "$DSTDIR/etc/resolv.conf"

# sshd not auto startup
F="$DSTDIR/etc/init.d/S50sshd"
test -f "$F" && mv "$F" "$DSTDIR/etc/init.d/sshd"

# rsa_id correct permissions
F="$DSTDIR/root/.ssh/id_rsa"
test -f "$F" && chmod 600 "$F"

exit 0

