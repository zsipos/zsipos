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
from os import uname
from sys import modules
from twisted.protocols.sip import parseURL, Request
from twisted.python.compat import long

from Branch import stringifyLogBranch
from gitversions import gitversions

class TimeMeasure(object):
    """
    A class to measure processing time.
    """
    
    samplecount = 0
    delta = max = accumulated = timedelta()
    min = timedelta(9999,0)
    name = "<anon>"
    
    def __init__(self, name):
        self.name = name
        
    def getDelta(self):
        return self.delta
    
    def getMin(self):
        return self.min
    
    def getMax(self):
        return self.max
    
    def getAvg(self):
        return self.accumulated / self.samplecount
    
    def start(self):
        self.starttime = datetime.now()
        
    def stop(self):
        self.delta = datetime.now() - self.starttime
        self.accumulated += self.delta
        self.samplecount += 1
        if self.delta < self.min:
            self.min = self.delta
        if self.delta > self.max:
            self.max = self.delta
            
    def toString(self):
        return "%s %f (avg=%f,min=%f,max=%f)" % (self.name, self.getDelta().total_seconds(), 
                                    self.getAvg().total_seconds(), 
                                    self.getMin().total_seconds(), 
                                    self.getMax().total_seconds())


class PYCALL:

    def __init__(self, func, args, kwargs):
        self.func   = func
        self.args   = args
        self.kwargs = kwargs
        
    def call(self):
        self.func(*self.args, **self.kwargs)


def parseAddress(address, host=None, port=None, clean=0):
    """Return (name, uri, params) for From/To/Contact header.

    @param clean: remove unnecessary info, usually for From and To headers.
    
    This is a fixed version of twisted ones.
    """
    address = address.strip()
    # simple 'sip:foo' case
    if address.startswith("sip:"):
        return "", parseURL(address, host=host, port=port), {}
    params = {}
    name, url = address.split("<", 1)
    name = name.strip()
    if name.startswith('"'):
        name = name[1:]
    if name.endswith('"'):
        name = name[:-1]
    url, paramstring = url.split(">", 1)
    url = parseURL(url, host=host, port=port)
    paramstring = paramstring.strip()
    if paramstring:
        for l in paramstring.split(";"):
            if not l:
                continue
            try:
                k, v = l.split("=")
                params[k] = v
            except:
                params[l] = None
    if clean:
        # rfc 2543 6.21
        url.ttl = None
        url.headers = {}
        url.transport = None
        url.maddr = None
    return name, url, params


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
    
def showversion():
    print('GIT-MAGIC:', hex(getGitMagic()))
    for i in ['FPGA-GIT', 'KERNEL-GIT']:
        print("%s: 0x%x" % (i, gitversions[i]))

