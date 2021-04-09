# SPDX-FileCopyrightText: 2021 Esther Bergter <esther.bergter@vipcomag.de>
#
# SPDX-License-Identifier: GPL-3.0-or-later

"""
Copyright (C) 2021 Esther Bergter

   This program is free software; you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation; either version 3 of the License, or
   (at your option) any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program; if not, write to the Free Software Foundation,
   Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301
"""
#
#configtext.pxi
#
# Author: Esther Bergter
#
# Version 1.0

cdef str pw_reset = 'pw_reset'
cdef str sshd_initd = '/etc/init.d/S50sshd'
cdef str already_current = 'you already have the current version'
cdef str section = 'gmitm'
cdef str alternate_partition='/tmp/alternate_partition'
cdef str versioncounter_path = '/versioncount'
cdef str versiontext_path = '/version.txt'
cdef str mountbase = '/dev/mmcblk0p'
cdef str partition_path = '/proc/device-tree/chosen/zsipos,partition'
cdef str bootversion_path = '/proc/device-tree/chosen/zsipos,boot-version'
cdef str update_file = 'update.txt'
cdef str updatetar_path = 'packages/'
cdef str testversion_path = 'testversion'
cdef str copylist_path = '/tmp/alternate_partition/root/config_list.txt'
cdef str local_archive_path = 'archive'
cdef str current_archive = local_archive_path
cdef str alternate_archive_path = '/tmp/alternate_partition/root/archive'
cdef str empty_label = 'archive                                                            '
cdef str str_hexdigest_matches = 'hexdigest matches, ok\n'
cdef str str_hexdigest_ignored = 'hexdigest ignored, ok\n'
#cdef str str_hexdigest_wrong = 'hexdigest does not match, not ok'
cdef str str_hexdigest_canceled = 'no hexdigest given, not ok\n'
cdef str str_update_started = 'Update started ...\n'
cdef str str_update_canceled = 'Update canceled\n'
cdef str str_update_failed = 'Update failed\n'
cdef str str_update_completed = 'Update completed\n'
cdef str str_download_started = 'Download started ...\n'
cdef str str_download_canceled = 'Download canceled\n'
cdef str str_download_failed = 'Download failed\n'
cdef str str_download_completed = 'Download done.\n'
cdef str str_unpack_started = 'Unpacking ...\n'
cdef str str_unpack_canceled = 'Unpack canceled\n'
cdef str str_unpack_failed = 'Unpack failed\n'
cdef str str_unpack_completed = 'Unpack done.\n'
cdef str str_copy_config = 'copying configuration, please wait\n'
cdef str str_copy_config_done = 'copy configuration done.\n'
cdef str str_sshd_first_start ='This is the first start of sshd. It will take around 5 minutes to generate server keys. Please stay patient.'

cdef str str_update_reboot_information = '\nNOTE: If reboot should fail, press display until it turns black. Device returns to current version.'

cdef str str_ip_config = 'Ip Config'
cdef str help_ip_config = """Setup your network configuration.

You can obtain your IP Address including the DNS setting automatically from a DHCP server or specify it manually.
In this case you can use either IPv4 or IPv6 address.

IPv4:

address: 123.45.67.89
mask: 255.255.255.0

IPv6:

address: 1abc:45.678::9a
mask: 64
"""

cdef str str_server = 'Server'
cdef str help_server = """SIP Proxy:

The name / Address and port of your SIP proxy

ICE Storage:

The URL of your ICE helper

http://name:port

STUN Server:

name:port

TURN Server:

name:port;u=user;p=pw

NTP Server:   time server

name
"""

cdef str str_logs = 'Logs'
# no log help

cdef str str_experts = 'Experts'
cdef str help_experts = """These settings should only be changed if you are aware of what you are doing! For normal operation please use the defaults.

Local Proxy:

This is the IP address of the zsipos box shown to the local IP phone. There is no reason to change the standard setting of 192.168.231.78. You must set this address in the local telephone as SIP proxy address.

skip zrtp1:

If your provider or your VOIP environment does not support ZRPT1 protocol, select 'skip zrtp1' in order to save time. Default is off. Generally, ZRTP1 is faster if supported.
"""

cdef str str_rootpw = 'Passwd'
# no help

cdef str str_reset = 'Reset'
cdef str help_reset ="""Power off/on always reboots.

Restart:

Restart the program.

Reconfigure Net:

Restart all services, thus refresh dhcp.

Reboot:

Reboot the machine.

Device Shutdown:

If you want to remove the SSD card, first shut down the unit, then unplug the power cord. Now you can safely remove the card.

Calibrate Display:

If the display seems out of position, you can calibrate it here.

Delete Trust Information:

Trusted partners and hosts are saved and re-used on next connection. If you delete the list, trust must be re-established.

Factory Reset:

Delete trust information, reset zsipos.cfg, reset network configuration, reset root password, reboot the system.
"""

cdef str str_sysinfo = 'SysInfo'
cdef str help_sysinfo ="""Click the buttons to show the content of the corresponding file or command.

Git Versions:

Shows the short git commit hashes of the components, that is the software version.
"""

cdef str str_update = 'Update'
# no help

