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
from SipProtocol import URL
from collections import OrderedDict
from twisted.internet.address import IPv4Address, IPv6Address

class MediaInfo(object):
    
    def __init__(self, value):
        self.value = value;
        self.headers = OrderedDict()
        
    def toString(self):
        s = self.value + '\r\n'
        for f, v in self.headers.items():
            for u in v:
                s += f + '=' + u + '\r\n'
        return s


class SDP(object):
    
    def __init__(self, value):
        self.headers = OrderedDict()
        self.parse(value)
        
    def parse(self, value):
        m = None
        for l in value.splitlines():
            f, v = l.split('=', 1)
            if f == 'm':
                v = MediaInfo(v)
                m = None
            o = m or self
            o.headers.setdefault(f, []).append(v)
            if f == 'm':
                m = v

    def toString(self):
        s = ''
        for f, v in self.headers.items():
            for u in v:
                s += f + '='
                if f == 'm':
                    s += u.toString()
                else:
                    s += u + '\r\n'
        return s
                

def sdpaddr2url(s, p):
    return URL(s.split()[2], port = int(p))


def url2sdpaddr(u):
    ret = "IN "
    if isinstance(u.host, IPv6Address):
        ret += "IP6 " + u.host.host
    else:
        ret += "IP4 "
        if isinstance(u.host, IPv4Address):
            ret += u.host.host
        else:
            ret += u.host            
    return ret
