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
from twisted.internet.protocol import DatagramProtocol
from twisted.protocols.sip import MessagesParser, parseViaHeader, URL
import logging

from config import config
import consts
from utils import TimeMeasure

log = logging.getLogger("sipprot")
logtime = None

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
