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
from datetime import datetime, timedelta
from os import uname, path
from sys import modules
from SipProtocol import Request
from twisted.python.compat import long

from Branch import stringifyLogBranch
from gitversions import gitversions,gitdates


class PYCALL:

    def __init__(self, func, args, kwargs):
        self.func   = func
        self.args   = args
        self.kwargs = kwargs
        
    def call(self):
        self.func(*self.args, **self.kwargs)


def stringifyAddress(name, uri, params):
    """
    Inverse parseAddress
    """
    result = '<' + uri.toString() + '>'
    if name:
        result = '"' + name + '" ' + result
    if params:
        for k, v in params.items():
            if v:
                result += ';' + k + '=' + v
            else:
                result += ';' + k
    return result

def stringifyLogAddr(addr):
    ret = addr.host
    if addr.port:
        ret += ":" + str(addr.port)
    return ret

def stringifyLogMsg(msg, full):
    ret = "<SIP "
    if isinstance(msg, Request):
        ret += msg.method + "," + str(msg.cseq[0])
    else:
        ret += "RESPONSE " + str(msg.code) + "," + msg.headers['cseq'][0]
    ret += "," + stringifyLogBranch(msg.via0.branch)
    ret += "," + msg.cid.rsplit('@', 1)[0] # china phones ...
    ret += ">"
    if full:
        ret += "\n" + msg.toString()
    return ret

def loadmodule(name):
    if uname()[4] == "x86_64":
        p = "host"
    else:
        p = "zsipos"
    fullname = name + '.' + p + '.' + name
    __import__(fullname)
    modules[name] = modules[fullname]
    
def getGitMagic():
    try: 
        with open("/sys/devices/platform/ff000000.zsiposver/zsiposver", 'r') as f:
            for l in f.readlines():
                n, v = l.split(':')
                gitversions[n] = long(v, 16)
    except:
        gitversions['FPGA-GIT'] = 0
        gitversions['KERNEL-GIT'] = 0
    res = 0
    for n, v in gitversions.items():
        if not n in ['FPGA-GIT', 'KERNEL-GIT']: 
            res = res ^ v
    return res
    
def tstr(timestamp):
    '''timestamp = unix time (sec) '''
    return datetime.fromtimestamp(timestamp).strftime('%Y-%b-%d %H:%M:%S')

def gitFormat(par):
    return '%s: 0x%x (%s)'%(par,gitversions[par],tstr(gitdates[par]) if par in gitdates else '---')

def showversion():
    print('GIT-MAGIC:', hex(getGitMagic()))
    for i in ['FPGA-GIT', 'KERNEL-GIT']:
        print(gitFormat(i))
        
def issel4():
    return path.exists(path.join("/", "proc", "net", "stack"))

def udpprotocol(isloc):
    if isloc and issel4():
        return (1<<15)
    else:
        return 0
    