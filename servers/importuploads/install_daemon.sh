# SPDX-FileCopyrightText: 2019 Stefan Adams <stefan.adams@vipcomag.de>
# SPDX-License-Identifier: GPL-3.0-or-later
DMnr=8
DMpar=DAEMON{$DMnr}
if o_get_config DMpar
then
  echo Daemon Nr $DMnr already exists
  exit
fi
user=ZSipOs_Import
o_put_user <<++
$ALPHAHOST
$OMEGAHOST
$user


n

1
++
a_put_user <<++
user


1
 0
 1
 2
 3
 4
 5
 6
 7
 8
 9
1
0
0
0
0



++
o_put_config DMpar $user@$ALPHAHOST
export SETUSER=$user
a_put_usrconf DM_HOST $LOCALHOSTNAME
a_put_usrconf DM_DIR `pwd`
a_put_usrconf DMcmd importZSipOs


