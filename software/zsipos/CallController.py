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


#
# OPTIONAL: RFC4028 (dialog timeout), RFC3264 (PRACK), RFC3311 (UPDATE), RFC6373 (summary extended offer / answer)
#


from copy import deepcopy
from twisted.internet import reactor
from twisted.internet.error import AlreadyCalled, AlreadyCancelled
from twisted.protocols.sip import Request, URL
from sys import exc_info
import logging

from config import config
import consts
from SDP import SDP, sdpaddr2url, url2sdpaddr
from utils import stringifyLogMsg
from rtp import CyZRTPSession  #@UnresolvedImport

log = logging.getLogger("gmitm.cc")

def fixConnection(sdp, raddr, raddrctrl):
    #
    # to be reimplemented ...
    #
    pcmu = False
    codecseen = False
    televseen = False
    fmtpseen = False
    ptime = 20
    pt = '101'
    c = sdp.headers.get('c', None)
    m = sdp.headers['m']
    o = sdp.headers['o']
    if not m:
        log.error('no m= - unable to fix.')
        log.error("sdp: " + sdp.toString())
        return
    if not c:
        c = m[0].headers.get('c')
        if not c:
            log.error('no c= - unable to fix.')
            log.error("sdp: " + sdp.toString())
            return
        sdp.headers['c'] = c
        del m[0].headers['c']
    mparts = m[0].value.split()
    laddr = sdpaddr2url(sdp.headers['c'][0], mparts[1])
    mparts[1] = str(raddr.port)
    m[0].value = " ".join(mparts)
    sdp.headers['c'] = [ url2sdpaddr(raddr) ]
    sdp.headers['m'] = [ m[0] ]
    oparts = o[0].split(' ')
    oparts[-1] = raddr.host
    o[0] = ' '.join(oparts)
    sdp.headers['o'] = [ o[0] ]
    a_new = []
    for i in m[0].headers['a']:
        try:
            aparts = i.split(':', 1)
        except IndexError:
            continue # does not contain ':'
        if aparts[0] == 'rtcp':
            a_new.append('rtcp:' + str(raddrctrl.port))
        elif aparts[0] == 'fmtp':
            fmtpseen = True
            a_new.append(i)
        elif aparts[0] == 'rtpmap':
            r = aparts[1].split(' ', 1)
            if r[1] == 'telephone-event/8000':
                televseen = True
                pt = r[0]
                a_new.append(i)
            elif aparts[1] in [ '0 PCMU/8000', '8 PCMA/8000' ]:
                if not codecseen:
                    codecseen = True
                    pcmu = aparts[1].startswith('0 PCMU/8000')
                a_new.append(i)
        elif aparts[0] == 'ptime':
            ptime = aparts[1]
            a_new.append(i)
        elif aparts[0] == 'crypto':
            pass
        else:
            a_new.append(i)
    if not televseen:
        a_new.append('rtpmap:' + pt + ' telephone-event/8000')
    if not fmtpseen:
        a_new.append('fmtp:' + pt + ' 0-15')
    m[0].headers['a'] = a_new
    if not pt in m[0].value:
        m[0].value += ' ' + pt
    laddrctrl = deepcopy(laddr)
    laddrctrl.port = laddrctrl.port + 1
    return (laddr, laddrctrl, (8000, int(ptime), pcmu, int(pt)))

def reduce2audio(sdp):
    m = sdp.headers.get('m')
    if m:
        for i in m:
            if not i.value.startswith('audio '):
                m.remove(i)
        if len(m):
            sdp.headers['m'] = [m[0]]
        else:
            del sdp.headers['m']
    return sdp

def setBody(msg, sdpstr):
    msg.body = sdpstr
    msg.headers['content-length'] = [ str(len(msg.body)) ]

def isSDP(msg):
    ct = msg.headers.get('content-type')
    if not ct:
        return False
    return ct[0].lower() == 'application/sdp'


class CallController(object):
    '''
    Manages one call (dialog).
    Rewrites SDP body to redirect rtp ports to re_rtpstream
    '''
    
    zsession = None
    
    def __init__(self, gmitm, msg, incoming):
        self.gmitm = gmitm
        self.logevents = config.getboolean(consts.SECTION, consts.LOGCCEVENTS)
        self.logmessages = config.getboolean(consts.SECTION, consts.LOGCCMESSAGES)
        self.logfullmessage = config.getboolean(consts.SECTION, consts.LOGFULLMESSAGE)
        self.cseq = msg.cseq
        self.cid = msg.cid
        self.incoming = incoming
        self.finalCode = None
        self.lastcseq = self.cseq
        self.cseqoffset = [0, 0]
        self.t3seconds = config.getfloat(consts.SECTION, consts.TIMERC)
        self.tsseconds = config.getfloat(consts.SECTION, consts.TIMERS)
        self.zsession = CyZRTPSession(self, consts.ZIDFILE)
        self.logtimer = config.getboolean(consts.SECTION, consts.LOGTIMERS)
        self.terminated = False
        self.clear_udp_addresses()
        self.on_created(msg)
        
    def clear_udp_addresses(self):
        self.addrFromSDP = [None, None]
        
    def close(self):
        self.cancelT3()
        self.cancelTS()
        if self.zsession:
            self.zsession.close()
            self.zsession = None
            
    #
    # control interface
    #
    def goSecure(self):
        self.zsession.goSecure()
            
    def setSASVerified(self):
        self.zsession.setSASVerified()
    
    def resetSASVerified(self):
        self.zsession.resetSASVerified()
        
    def acceptEnrollment(self, accepted):
        self.zsession.acceptEnrollment(accepted)
    
    def get_is_incoming(self):
        return self.incoming
    
    def get_is_handshake(self):
        return self.zsession.get_is_handshake()
    
    def getStatus(self):
        '''
        returns a dict of status information
        '''
        if not self.zsession:
            return None
        return self.zsession.getStatus()

    #
    #
    #

    def forwardDlgMessage(self, msg, external):
        '''
        forward a message to the proper destination.
        '''
        return self.gmitm.forwardMessage(msg, external)
        
    def forwardInDlgMessage(self, msg, external):
        '''
        forward a message to the proper destination.
        fixes in-dlg cseq.
        '''
        if isinstance(msg, Request):
            cseq = msg.cseq[0] + self.cseqoffset[external]
        else:
            cseq = msg.cseq[0] - self.cseqoffset[external]
        msg.headers['cseq'] = [ str(cseq) + " " + msg.cseq[1] ]
        return self.gmitm.forwardMessage(msg, external)
        
    def handle_request(self, msg, external):
        self.resetT3()
        if msg.cseq[0] == self.cseq[0]:
            return self.handle_dlg_request(msg, external)
        else:
            return self.handle_indlg_request(msg, external)
        
    def handle_dlg_request(self, msg, external):
        method = msg.method
        if method == 'INVITE': 
            self.clear_udp_addresses()
            if isSDP(msg):
                self.fixSDP(msg, external)
        elif method == 'BYE':
            self.startTS()
        elif method == 'CANCEL':
            self.startTS()
        elif method == 'ACK':
            # final state
            if isSDP(msg):
                self.fixSDP(msg, external, answer = True)
            if self.finalCode == 200:
                self.on_connected(msg)
            else:
                self.on_terminated(msg)
        return self.forwardDlgMessage(msg, external)
    
    def handle_indlg_request(self, msg, external):
        method = msg.method
        if method == 'INVITE':
            self.resetT3()
            self.clear_udp_addresses()
            if isSDP(msg):
                self.fixSDP(msg, external)
        elif method == 'ACK':
            # final state
            self.cancelT3()
            if isSDP(msg):
                self.fixSDP(msg, external, answer = True)
        elif method == 'BYE':
            self.startTS()
        elif method == 'INFO':
            log.debug(msg.body)
        return self.forwardInDlgMessage(msg, external)
        
    def handle_response(self, msg, external):
        self.resetT3()
        if msg.cseq[0] == self.cseq[0]:
            return self.handle_dlg_response(msg, external)
        else:
            return self.handle_indlg_reponse(msg, external)
        
    def handle_dlg_response(self, msg, external):
        method = msg.cseq[1]
        if method == 'INVITE': 
            if msg.code >= 200:
                self.finalCode = msg.code
                if isSDP(msg):
                    self.fixSDP(msg, external, answer = True)
            else:
                self.cleanPrack(msg)
                self.on_progress(msg)
        elif method == 'BYE':
            # final disconnect
            self.on_terminated(msg)
        elif method == 'CANCEL':
            if not self.finalCode:
                self.finalCode = 487
            self.on_terminated(msg)
        return self.forwardDlgMessage(msg, external)
    
    def handle_indlg_reponse(self, msg, external):
        method = msg.cseq[1]
        if method == 'INVITE':
            if msg.code >= 200:
                if isSDP(msg):
                    self.fixSDP(msg, external, answer = True)
            else:
                self.cleanPrack(msg)
                self.on_progress(msg)                
        elif method == 'BYE':
            # final disconnect
            self.on_terminated(msg)
        return self.forwardInDlgMessage(msg, external)
    
    def cleanPrack(self, msg):
        if not isSDP(msg):
            return
        del msg.headers['content-type']
        setBody(msg, "")
            
    def fixSDP(self, msg, external, answer = False):
        sdp = reduce2audio(SDP(msg.body))
        if external:
            url1 = self.zsession.locGetAddress()
            url2 = self.zsession.locGetCtrlAddress()
        else:
            url1 = self.zsession.extGetAddress()
            url2 = self.zsession.extGetCtrlAddress()
        self.addrFromSDP[external] = fixConnection(sdp, URL(url1[0], port = url1[1]), URL(url2[0], port = url2[1]))
        setBody(msg, sdp.toString())
        if answer:
            self.zsession.setAudioInfo(self.addrFromSDP[external][2])
        if self.addrFromSDP[False] and self.addrFromSDP[True]:
            url1, url2, _ = self.addrFromSDP[False]
            self.zsession.locSetDstAddress((url1.host, url1.port))
            self.zsession.locSetDstCtrlAddress((url2.host, url2.port))
            url1, url2, _ = self.addrFromSDP[True]
            self.zsession.extSetDstAddress((url1.host, url1.port))
            self.zsession.extSetDstCtrlAddress((url2.host, url2.port))
            self.zsession.addressesReady()
        
    def logCCEvent(self, txt, msg):
        log.debug(txt)
        if self.logmessages:
            if msg:
                log.debug("cc message: %s", stringifyLogMsg(msg, self.logfullmessage))
            else:
                log.debug("cc T3/TS timeout")
                
    # cc callbacks
        
    def on_created(self, msg):
        self.startT3()
        if self.logevents:
            self.logCCEvent("**call created:" + self.cid, msg)
        self.gmitm.on_call_created(self, msg)
            
    def on_progress(self, msg):
        if self.logevents:
            self.logCCEvent("**call progress:%s, code=%d" % (self.cid, msg.code), msg)
        self.gmitm.on_call_progress(self, msg)
        
    def on_connected(self, msg):
        self.cancelT3()
        self.cancelTS()
        if self.terminated:
            return
        if self.logevents:
            self.logCCEvent("**call connected:" + self.cid, msg)
        self.gmitm.on_call_connected(self, msg)
    
    def on_terminated(self, msg):
        self.cancelT3()
        self.cancelTS()
        if self.terminated:
            return
        self.terminated = True
        if self.logevents:
            self.logCCEvent("**call terminated:%s, finalCode=%d" % (self.cid, self.finalCode), msg)
        self.gmitm.on_call_terminated(self, msg, self.finalCode)
        
    # crypto callbacks
        
    def on_start_crypto_handshake(self):
        self.gmitm.on_start_crypto_handshake(self)
    
    def on_stop_crypto_handshake(self):
        self.gmitm.on_stop_crypto_handshake(self)
        
    def on_crypto_state_info(self, state):
        self.gmitm.on_crypto_state_info(self, state)
    
    def on_secure_on(self, cipher, sas, verified):
        self.gmitm.on_secure_on(self, cipher, sas, verified)
    
    def on_secure_off(self):
        self.gmitm.on_secure_off(self)
    
    def on_zrtp_failed(self):
        self.gmitm.on_zrtp_failed(self)

    def on_zrtp_ask_enrollment(self, info):
        self.gmitm.on_zrtp_ask_enrollment(self, info)

    def on_zrtp_inform_enrollent(self, info):
        self.gmitm.on_zrtp_inform_enrollent(self, info)

    def on_zrtp_sign_sas(self, sasHash):
        self.gmitm.on_zrtp_sign_sas(self, sasHash)

    def on_zrtp_check_sas_signature(self, sasHash):
        return self.gmitm.on_zrtp_check_sas_signature(self, sasHash)
    
    #
    # timeouts
    #
    def startT3(self):
        self.t3 = reactor.callLater(self.t3seconds, self.on_T3)  # @UndefinedVariable
        if self.logtimer:
            log.debug("startT3(%s,%d)", self.cid, self.t3seconds)
    
    def on_T3(self):
        if self.logtimer:
            log.debug("fireT3(%s)", self.cid)
        self.finalCode = 408
        self.on_terminated(None)
            
    def resetT3(self):
        try:
            self.t3.reset(self.t3seconds)
            if self.logtimer:
                log.debug("resetT3(%s,%d)", self.cid, self.t3seconds)
        except Exception as e:
            if type(e) in [AttributeError, AlreadyCalled, AlreadyCancelled]:
                return
            log.debug(e, exc_info = exc_info())
        
    def cancelT3(self):
        try:
            self.t3.cancel()
            if self.logtimer:
                log.debug("cancelT3(%s)", self.cid)
        except Exception as e:
            if type(e) in [AttributeError, AlreadyCalled, AlreadyCancelled]:
                return
            log.debug(e, exc_info = exc_info())
        finally:
            self.t3 = None
    
    def startTS(self):
        self.cancelTS()
        self.ts = reactor.callLater(self.tsseconds, self.on_TS)  # @UndefinedVariable
        if self.logtimer:
            log.debug("startTS(%s,%d)", self.cid, self.tsseconds)
    
    def on_TS(self):
        if self.logtimer:
            log.debug("fireTS(%s)", self.cid)
        if not self.finalCode:
            self.finalCode = 487
        self.on_terminated(None)
            
    def cancelTS(self):
        try:
            self.ts.cancel()
            if self.logtimer:
                log.debug("cancelTS(%s)", self.cid)
        except Exception as e:
            if type(e) in [AttributeError, AlreadyCalled, AlreadyCancelled]:
                return
            log.debug(e, exc_info = exc_info())
        finally:
            self.ts = None
    
