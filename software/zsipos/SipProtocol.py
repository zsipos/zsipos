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

from datetime import datetime, timedelta
from collections import OrderedDict
import logging
import warnings

from twisted.protocols import basic
from twisted.internet.protocol import DatagramProtocol
from twisted.python.compat import _PY3, unicode


from config import config
import consts

log = logging.getLogger("sipprot")
logtime = None


PORT = 5060

# SIP headers have short forms
shortHeaders = {"call-id": "i",
                "contact": "m",
                "content-encoding": "e",
                "content-length": "l",
                "content-type": "c",
                "from": "f",
                "subject": "s",
                "to": "t",
                "via": "v",
                }

longHeaders = {}
for k, v in shortHeaders.items():
    longHeaders[v] = k
del k, v

statusCodes = {
    100: "Trying",
    180: "Ringing",
    181: "Call Is Being Forwarded",
    182: "Queued",
    183: "Session Progress",

    200: "OK",

    300: "Multiple Choices",
    301: "Moved Permanently",
    302: "Moved Temporarily",
    303: "See Other",
    305: "Use Proxy",
    380: "Alternative Service",

    400: "Bad Request",
    401: "Unauthorized",
    402: "Payment Required",
    403: "Forbidden",
    404: "Not Found",
    405: "Method Not Allowed",
    406: "Not Acceptable",
    407: "Proxy Authentication Required",
    408: "Request Timeout",
    409: "Conflict", # Not in RFC3261
    410: "Gone",
    411: "Length Required", # Not in RFC3261
    413: "Request Entity Too Large",
    414: "Request-URI Too Large",
    415: "Unsupported Media Type",
    416: "Unsupported URI Scheme",
    420: "Bad Extension",
    421: "Extension Required",
    423: "Interval Too Brief",
    480: "Temporarily Unavailable",
    481: "Call/Transaction Does Not Exist",
    482: "Loop Detected",
    483: "Too Many Hops",
    484: "Address Incomplete",
    485: "Ambiguous",
    486: "Busy Here",
    487: "Request Terminated",
    488: "Not Acceptable Here",
    491: "Request Pending",
    493: "Undecipherable",

    500: "Internal Server Error",
    501: "Not Implemented",
    502: "Bad Gateway", # No donut
    503: "Service Unavailable",
    504: "Server Time-out",
    505: "SIP Version not supported",
    513: "Message Too Large",

    600: "Busy Everywhere",
    603: "Decline",
    604: "Does not exist anywhere",
    606: "Not Acceptable",
}

specialCases = {
    'cseq': 'CSeq',
    'call-id': 'Call-ID',
    'www-authenticate': 'WWW-Authenticate',
}


def dashCapitalize(s):
    """
    Capitalize a string, making sure to treat '-' as a word separator
    """
    return '-'.join([ x.capitalize() for x in s.split('-')])


def unq(s):
    if s[0] == s[-1] == '"':
        return s[1:-1]
    return s



_absent = object()

class Via(object):
    """
    A L{Via} is a SIP Via header, representing a segment of the path taken by
    the request.

    See RFC 3261, sections 8.1.1.7, 18.2.2, and 20.42.

    @ivar transport: Network protocol used for this leg. (Probably either "TCP"
    or "UDP".)
    @type transport: C{str}
    @ivar branch: Unique identifier for this request.
    @type branch: C{str}
    @ivar host: Hostname or IP for this leg.
    @type host: C{str}
    @ivar port: Port used for this leg.
    @type port C{int}, or None.
    @ivar rportRequested: Whether to request RFC 3581 client processing or not.
    @type rportRequested: C{bool}
    @ivar rportValue: Servers wishing to honor requests for RFC 3581 processing
    should set this parameter to the source port the request was received
    from.
    @type rportValue: C{int}, or None.

    @ivar ttl: Time-to-live for requests on multicast paths.
    @type ttl: C{int}, or None.
    @ivar maddr: The destination multicast address, if any.
    @type maddr: C{str}, or None.
    @ivar hidden: Obsolete in SIP 2.0.
    @type hidden: C{bool}
    @ivar otherParams: Any other parameters in the header.
    @type otherParams: C{dict}
    """

    def __init__(self, host, port=PORT, transport="UDP", ttl=None,
                 hidden=False, received=None, rport=_absent, branch=None,
                 maddr=None, **kw):
        """
        Set parameters of this Via header. All arguments correspond to
        attributes of the same name.

        To maintain compatibility with old SIP
        code, the 'rport' argument is used to determine the values of
        C{rportRequested} and C{rportValue}. If None, C{rportRequested} is set
        to True. (The deprecated method for doing this is to pass True.) If an
        integer, C{rportValue} is set to the given value.

        Any arguments not explicitly named here are collected into the
        C{otherParams} dict.
        """
        self.transport = transport
        self.host = host
        self.port = port
        self.ttl = ttl
        self.hidden = hidden
        self.received = received
        if rport is True:
            warnings.warn(
                "rport=True is deprecated since Twisted 9.0.",
                DeprecationWarning,
                stacklevel=2)
            self.rportValue = None
            self.rportRequested = True
        elif rport is None:
            self.rportValue = None
            self.rportRequested = True
        elif rport is _absent:
            self.rportValue = None
            self.rportRequested = False
        else:
            self.rportValue = rport
            self.rportRequested = False

        self.branch = branch
        self.maddr = maddr
        self.otherParams = kw


    def _getrport(self):
        """
        Returns the rport value expected by the old SIP code.
        """
        if self.rportRequested == True:
            return True
        elif self.rportValue is not None:
            return self.rportValue
        else:
            return None


    def _setrport(self, newRPort):
        """
        L{Base._fixupNAT} sets C{rport} directly, so this method sets
        C{rportValue} based on that.

        @param newRPort: The new rport value.
        @type newRPort: C{int}
        """
        self.rportValue = newRPort
        self.rportRequested = False

    rport = property(_getrport, _setrport)

    def toString(self):
        """
        Serialize this header for use in a request or response.
        """
        s = "SIP/2.0/%s %s:%s" % (self.transport, self.host, self.port)
        if self.hidden:
            s += ";hidden"
        for n in "ttl", "branch", "maddr", "received":
            value = getattr(self, n)
            if value is not None:
                s += ";%s=%s" % (n, value)
        if self.rportRequested:
            s += ";rport"
        elif self.rportValue is not None:
            s += ";rport=%s" % (self.rport,)

        etc = sorted(self.otherParams.items())
        for k, v in etc:
            if v is None:
                s += ";" + k
            else:
                s += ";%s=%s" % (k, v)
        return s



def parseViaHeader(value):
    """
    Parse a Via header.

    @return: The parsed version of this header.
    @rtype: L{Via}
    """
    parts = value.split(";")
    sent, params = parts[0], parts[1:]
    protocolinfo, by = sent.split(" ", 1)
    by = by.strip()
    result = {}
    pname, pversion, transport = protocolinfo.split("/")
    if pname != "SIP" or pversion != "2.0":
        raise ValueError("wrong protocol or version: %r" % (value,))
    result["transport"] = transport
    if ":" in by:
        host, port = by.split(":")
        result["port"] = int(port)
        result["host"] = host
    else:
        result["host"] = by
    for p in params:
        # It's the comment-striping dance!
        p = p.strip().split(" ", 1)
        if len(p) == 1:
            p, comment = p[0], ""
        else:
            p, comment = p
        if p == "hidden":
            result["hidden"] = True
            continue
        parts = p.split("=", 1)
        if len(parts) == 1:
            name, value = parts[0], None
        else:
            name, value = parts
            if name in ("rport", "ttl"):
                value = int(value)
        result[name] = value
    return Via(**result)



class URL:
    """
    A SIP URL.
    """

    def __init__(self, host, username=None, password=None, port=None,
                 transport=None, usertype=None, method=None,
                 ttl=None, maddr=None, tag=None, other=None, headers=None):
        self.username = username
        self.host = host
        self.password = password
        self.port = port
        self.transport = transport
        self.usertype = usertype
        self.method = method
        self.tag = tag
        self.ttl = ttl
        self.maddr = maddr
        if other == None:
            self.other = []
        else:
            self.other = other
        if headers == None:
            self.headers = {}
        else:
            self.headers = headers


    def toString(self):
        l = []; w = l.append
        w("sip:")
        if self.username != None:
            w(self.username)
            if self.password != None:
                w(":%s" % self.password)
            w("@")
        w(self.host)
        if self.port != None:
            w(":%d" % self.port)
        if self.usertype != None:
            w(";user=%s" % self.usertype)
        for n in ("transport", "ttl", "maddr", "method", "tag"):
            v = getattr(self, n)
            if v != None:
                w(";%s=%s" % (n, v))
        for v in self.other:
            w(";%s" % v)
        if self.headers:
            w("?")
            w("&".join([("%s=%s" % (specialCases.get(h) or dashCapitalize(h), v)) for (h, v) in self.headers.items()]))
        return "".join(l)


    def __str__(self):
        return self.toString()


    def __repr__(self):
        return '<URL %s:%s@%s:%r/%s>' % (self.username, self.password, self.host, self.port, self.transport)



def parseURL(url, host=None, port=None):
    """
    Return string into URL object.

    URIs are of form 'sip:user@example.com'.
    """
    d = {}
    if not url.startswith("sip:"):
        raise ValueError("unsupported scheme: " + url[:4])
    parts = url[4:].split(";")
    userdomain, params = parts[0], parts[1:]
    udparts = userdomain.split("@", 1)
    if len(udparts) == 2:
        userpass, hostport = udparts
        upparts = userpass.split(":", 1)
        if len(upparts) == 1:
            d["username"] = upparts[0]
        else:
            d["username"] = upparts[0]
            d["password"] = upparts[1]
    else:
        hostport = udparts[0]
    if hostport.startswith("["): #maybe ipv6 address
        hpparts = hostport.rsplit(":", 1)
    else:
        hpparts = hostport.split(":", 1)
    if len(hpparts) == 1:
        d["host"] = hpparts[0]
    else:
        d["host"] = hpparts[0]
        d["port"] = int(hpparts[1])
    if host != None:
        d["host"] = host
    if port != None:
        d["port"] = port
    for p in params:
        if p == params[-1] and "?" in p:
            d["headers"] = h = {}
            p, headers = p.split("?", 1)
            for header in headers.split("&"):
                k, v = header.split("=")
                h[k] = v
        nv = p.split("=", 1)
        if len(nv) == 1:
            d.setdefault("other", []).append(p)
            continue
        name, value = nv
        if name == "user":
            d["usertype"] = value
        elif name in ("transport", "ttl", "maddr", "method", "tag"):
            if name == "ttl":
                value = int(value)
            d[name] = value
        else:
            d.setdefault("other", []).append(p)
    return URL(**d)



def cleanRequestURL(url):
    """
    Clean a URL from a Request line.
    """
    url.transport = None
    url.maddr = None
    url.ttl = None
    url.headers = {}



def parseAddress(address, host=None, port=None, clean=0):
    """Return (name, uri, params) for From/To/Contact header.

    @param clean: remove unnecessary info, usually for From and To headers.
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



class Message:
    """
    A SIP message.
    """

    length = None

    def __init__(self):
        self.headers = OrderedDict() # Map name to list of values
        self.body = ""
        self.finished = 0


    def addHeader(self, name, value):
        name = name.lower()
        name = longHeaders.get(name, name)
        if name == "content-length":
            self.length = int(value)
        self.headers.setdefault(name,[]).append(value)


    def bodyDataReceived(self, data):
        self.body += data


    def creationFinished(self):
        if (self.length != None) and (self.length != len(self.body)):
            raise ValueError("wrong body length")
        self.finished = 1


    def toString(self):
        s = "%s\r\n" % self._getHeaderLine()
        for n, vs in self.headers.items():
            for v in vs:
                s += "%s: %s\r\n" % (specialCases.get(n) or dashCapitalize(n), v)
        s += "\r\n"
        s += self.body
        return s


    def _getHeaderLine(self):
        raise NotImplementedError



class Request(Message):
    """
    A Request for a URI
    """

    def __init__(self, method, uri, version="SIP/2.0"):
        Message.__init__(self)
        self.method = method
        if isinstance(uri, URL):
            self.uri = uri
        else:
            self.uri = parseURL(uri)
            cleanRequestURL(self.uri)


    def __repr__(self):
        return "<SIP Request %d:%s %s>" % (id(self), self.method, self.uri.toString())


    def _getHeaderLine(self):
        return "%s %s SIP/2.0" % (self.method, self.uri.toString())



class Response(Message):
    """
    A Response to a URI Request
    """

    def __init__(self, code, phrase=None, version="SIP/2.0"):
        Message.__init__(self)
        self.code = code
        if phrase == None:
            phrase = statusCodes[code]
        self.phrase = phrase


    def __repr__(self):
        return "<SIP Response %d:%s>" % (id(self), self.code)


    def _getHeaderLine(self):
        return "SIP/2.0 %s %s" % (self.code, self.phrase)



class MessagesParser(basic.LineReceiver):
    """
    A SIP messages parser.

    Expects dataReceived, dataDone repeatedly,
    in that order. Shouldn't be connected to actual transport.
    """

    version = "SIP/2.0"
    acceptResponses = 1
    acceptRequests = 1
    state = "firstline" # Or "headers", "body" or "invalid"

    debug = 0

    def __init__(self, messageReceivedCallback):
        self.messageReceived = messageReceivedCallback
        self.reset()


    def reset(self, remainingData=""):
        self.state = "firstline"
        self.length = None # Body length
        self.bodyReceived = 0 # How much of the body we received
        self.message = None
        self.header = None
        self.setLineMode(remainingData)


    def invalidMessage(self):
        self.state = "invalid"
        self.setRawMode()


    def dataDone(self):
        """
        Clear out any buffered data that may be hanging around.
        """
        self.clearLineBuffer()
        if self.state == "firstline":
            return
        if self.state != "body":
            self.reset()
            return
        if self.length == None:
            # No content-length header, so end of data signals message done
            self.messageDone()
        elif self.length < self.bodyReceived:
            # Aborted in the middle
            self.reset()
        else:
            # We have enough data and message wasn't finished? something is wrong
            raise RuntimeError("this should never happen")


    def dataReceived(self, data):
        try:
            if isinstance(data, unicode):
                data = data.encode("utf-8")
            basic.LineReceiver.dataReceived(self, data)
        except:
            log.err()
            self.invalidMessage()


    def handleFirstLine(self, line):
        """
        Expected to create self.message.
        """
        raise NotImplementedError


    def lineLengthExceeded(self, line):
        self.invalidMessage()


    def lineReceived(self, line):
        if _PY3 and isinstance(line, bytes):
            line = line.decode("utf-8")

        if self.state == "firstline":
            while line.startswith("\n") or line.startswith("\r"):
                line = line[1:]
            if not line:
                return
            try:
                a, b, c = line.split(" ", 2)
            except ValueError:
                self.invalidMessage()
                return
            if a == "SIP/2.0" and self.acceptResponses:
                # Response
                try:
                    code = int(b)
                except ValueError:
                    self.invalidMessage()
                    return
                self.message = Response(code, c)
            elif c == "SIP/2.0" and self.acceptRequests:
                self.message = Request(a, b)
            else:
                self.invalidMessage()
                return
            self.state = "headers"
            return
        else:
            assert self.state == "headers"
        if line:
            # Multiline header
            if line.startswith(" ") or line.startswith("\t"):
                name, value = self.header
                self.header = name, (value + line.lstrip())
            else:
                # New header
                if self.header:
                    self.message.addHeader(*self.header)
                    self.header = None
                try:
                    name, value = line.split(":", 1)
                except ValueError:
                    self.invalidMessage()
                    return
                self.header = name, value.lstrip()
                # XXX we assume content-length won't be multiline
                if name.lower() == "content-length":
                    try:
                        self.length = int(value.lstrip())
                    except ValueError:
                        self.invalidMessage()
                        return
        else:
            # CRLF, we now have message body until self.length bytes,
            # or if no length was given, until there is no more data
            # from the connection sending us data.
            self.state = "body"
            if self.header:
                self.message.addHeader(*self.header)
                self.header = None
            if self.length == 0:
                self.messageDone()
                return
            self.setRawMode()


    def messageDone(self, remainingData=""):
        assert self.state == "body"
        self.message.creationFinished()
        self.messageReceived(self.message)
        self.reset(remainingData)


    def rawDataReceived(self, data):
        assert self.state in ("body", "invalid")
        if _PY3 and isinstance(data, bytes):
            data = data.decode("utf-8")
        if self.state == "invalid":
            return
        if self.length == None:
            self.message.bodyDataReceived(data)
        else:
            dataLen = len(data)
            expectedLen = self.length - self.bodyReceived
            if dataLen > expectedLen:
                self.message.bodyDataReceived(data[:expectedLen])
                self.messageDone(data[expectedLen:])
                return
            else:
                self.bodyReceived += dataLen
                self.message.bodyDataReceived(data)
                if self.bodyReceived == self.length:
                    self.messageDone()



class SipProtocol(DatagramProtocol):
    """
    Base class for SIP clients and servers.
    This is a simplified version of twisted ones.
    """

    def __init__(self, rcvCallback):
        global logtime, measure
        self.messages = []
        self.parser = MessagesParser(self.addMessage)
        self.rcvCallback = rcvCallback
        self.timeoutval = timedelta(seconds=500/1000.0)
        if logtime == None:
            logtime = config.getboolean(consts.SECTION, consts.LOGSIPTIMING)
            if logtime:
                measure = TimeMeasure("total   sipmsg") 
        if logtime:
            self.measureparse   = TimeMeasure("parse   sipmsg")
            self.measureprocess = TimeMeasure("process sipmsg")

    def addMessage(self, msg):
        msg.timestamp = self.timestamp
        self.messages.append(msg)

    def datagramReceived(self, data, addr):
        self.timestamp = datetime.now()
        if logtime:
            measure.start()
            self.measureparse.start()
        self.parser.dataReceived(data)
        self.parser.dataDone()
        if logtime:
            self.measureparse.stop()
            log.debug(self.measureparse.toString())
        for m in self.messages:
            #?self._fixupNAT(m, addr)
            if logtime:
                self.measureprocess.start()
            #so essential for everything...
            m.via0 = parseViaHeader(m.headers['via'][0])
            cseq = m.headers['cseq'][0].split()
            m.cseq = (int(cseq[0]), cseq[1])
            m.cid = m.headers['call-id'][0]
            #
            self.rcvCallback(m, URL(host = addr[0], port = addr[1]))
            if logtime:
                self.measureprocess.stop()
                log.debug(self.measureprocess.toString())
        self.messages = []
        if logtime:
            measure.stop()
            log.debug(measure.toString())

    def sendMessage(self, addr, message):
        """
        Send a message.

        @param addr: C{URL}. This should be a *physical* URL, not a logical one.
        @param message: The message to send.
        
        returns the raw message data
        """
        if addr.transport not in ("UDP", "udp", None):
            raise RuntimeError("malformed address " + addr.toString() + ", only UDP currently supported")
        data = message.toString()
        if isinstance(data, str):
            data = data.encode("utf8")
        self.transport.write(data, (addr.host, addr.port))
        return data
    
    def sendRawData(self, addr, data):
        """
        Send raw data.

        @param addr: C{URL}. This should be a *physical* URL, not a logical one.
        @param data: The data to send.
        """
        if addr.transport not in ("UDP", "udp", None):
            raise RuntimeError("malformed address " + addr.toString() + ", only UDP currently supported")
        self.transport.write(data, (addr.host, addr.port))



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
