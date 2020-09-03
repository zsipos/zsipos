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
from os import uname
from time import sleep
from twisted.internet import reactor
from twisted.internet.error import AlreadyCalled, AlreadyCancelled
from SipProtocol import Request
import logging

from config import config
import consts

log = logging.getLogger("gmitm.bm")

def stringifyLogBranch(branch):
    if isinstance(branch, Branch):
        branch = branch.branch
    if branch.startswith("z9hG4bK"):
        branch = "*" + branch[7:]
    return branch
        
class Branch(object):

    def __init__(self, gmitm, msg, external):
        self.branch = msg.via0.branch
        self.gmitm = gmitm
        self.cseq = msg.cseq
        self.isInvite = msg.method == 'INVITE'
        self.external = external
        self.cachedRequests  = {} # dict "method" of (msg, raw string of transformed message, addr)
        self.cachedResponses = {} # dict "method" of (msg, raw string of transformed message, addr, code)
        self.logtimer = config.getboolean(consts.SECTION, consts.LOGTIMERS)
        self.logtimer = False # too many output
        self.logbm = config.getboolean(consts.SECTION, consts.LOGBMEVENTS)
        self.sipdelay = config.getboolean(consts.SECTION, consts.SIPDELAY)
        self.log("created")
        if self.isInvite:
            self.set_timeout(config.getfloat(consts.SECTION, consts.TIMERB))
        else:
            self.set_timeout(config.getfloat(consts.SECTION, consts.TIMERF))
    
    def log(self, logmsg):
        if not self.logbm:
            return
        log.debug("branch %s %s", stringifyLogBranch(self.branch), logmsg)
        
    def messageReceived(self, msg, addr, external):
        if isinstance(msg, Request):
            self.handle_request(msg, addr, external)
        else:
            self.handle_response(msg, addr, external)
            
    def forwardCacheItem(self, ci, external):
        addr = ci[2]
        self.gmitm.logIOMesssage(ci[0], addr, False, not external)
        self.gmitm.forwardRawData(ci[1], addr, external)
            
    def handle_request(self, msg, addr, external):
        if external != self.external:
            log.warning("request received with wrong direction:")
            log.warning(msg.toString())
        ci = self.cachedResponses.get(msg.method)
        if ci and ci[3] >= 200:
            self.log("replying with cached response")
            self.forwardCacheItem(ci, not external)
            return
        ci = self.cachedRequests.get(msg.method)
        if ci:
            self.log("using cached request")
            self.forwardCacheItem(ci, external)
            return
        if self.sipdelay and uname()[4] != "openrisc":
            sleep(0.4)
        ci = self.gmitm.handle_request(msg, addr, external)
        if ci:
            self.cachedRequests[msg.method] = (msg, ci[0], ci[1])
            if self.isInvite:
                if msg.method == 'ACK':
                    self.completed()
    
    def handle_response(self, msg, addr, external):
        if external == self.external:
            log.warning("response received with wrong direction:")
            log.warning(msg.toString())
        ci = self.cachedResponses.get(msg.cseq[1])
        if ci and ci[3] == msg.code: #maybe final code has changed ...
            self.log("using cached response")
            self.forwardCacheItem(ci, external)
            return
        if self.sipdelay and uname()[4] != "openrisc":
            sleep(0.4)
        msgstr, addr = self.gmitm.handle_response(msg, addr, external)
        if msgstr:
            self.cachedResponses[msg.cseq[1]] = (msg, msgstr, addr, msg.code)
            if msg.code >= 200:
                self.completed()
        
    def set_timeout(self, val):
        if self.logtimer:
            log.debug("timer set(%s, %f)", stringifyLogBranch(self), val)
        self.timer = reactor.callLater(val, self.timedout)  # @UndefinedVariable

    def reset_timeout(self, val):
        try:
            if self.logtimer:
                log.debug("timer reset(%s, %f)", stringifyLogBranch(self), val)
            self.timer.reset(val)
        except AlreadyCalled:
            pass
        except AlreadyCancelled:
            pass
        except Exception as e:
            log.debug(e)
    
    def cancel_timeout(self):
        try:
            if self.logtimer:
                log.debug("timer cancel(%s)", stringifyLogBranch(self))
            self.timer.cancel()
        except AlreadyCalled:
            pass
        except AlreadyCancelled:
            pass
        except Exception as e:
            log.debug(e)
    
    def timedout(self):
        self.terminated()
        
    def completed(self):
        self.log("completed")
        if self.isInvite:
            self.reset_timeout(config.getfloat(consts.SECTION, consts.TIMERD))
        else:
            self.reset_timeout(config.getfloat(consts.SECTION, consts.TIMERK))
        
    def terminated(self):
        self.cancel_timeout()
        self.log("deleted")
        self.gmitm.delBranch(self)
        if self.logbm:
            log.debug("active branches=%d", len(self.gmitm.branchmap))
