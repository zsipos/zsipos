# SPDX-FileCopyrightText: 2019 Stefan Adams <stefan.adams@vipcomag.de
#
# SPDX-License-Identifier: GPL-3.0-or-later

"""
Copyright (C) 2017 Stefan Adams

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
import fcntl
import re
import socket
import struct

def get_ip_address(ifname):
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    return socket.inet_ntoa(fcntl.ioctl(
        s.fileno(),
        0x8915,  # SIOCGIFADDR
        struct.pack('256s', ifname[:15].encode("utf8"))
    )[20:24])

def get_default_gateway_linux():
    """Read the default gateway directly from /proc."""
    with open("/proc/net/route") as fh:
        for line in fh:
            fields = line.strip().split()
            if fields[1] != '00000000' or not int(fields[3], 16) & 2:
                continue

            return socket.inet_ntoa(struct.pack("=L", int(fields[2], 16)))

def split_host_port(val):
    #debug("split_host_port " + input)
    re_trivial = re.compile('(.*)')
    if val.startswith('['): # ipv6 mit port
        re_v6 = re.compile('\[([^\]]*)\]:(\d+)')
        result = re_v6.match(val)
    elif val.count(':') > 1: # ipv6 ohne port
        result = re_trivial.match(val)
    elif val.count(':') == 1: # nicht v6, mit port 
        re_host = re.compile('((\w+[\.]?)+):(\d+)')
        re_v4 = re.compile('(\d[^:]*):(\d+)')
        result = re_host.match(val)
        if not result:
            result = re_v4.match(val)
    else:
        result = re_trivial.match(val)
    if result is not None:
        if result.lastindex >= 2:
            return result.group(1, result.lastindex)
        elif result.lastindex == 1:
            return (result.group(0), "")
# split_host_port

