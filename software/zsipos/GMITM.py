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
import gc
import logging

from twisted.protocols.sip import Request, parseURL
from twisted.internet import reactor

from Branch import Branch
from CallController import CallController
from config import config
import consts
from SipProtocol import SipProtocol
from utils import parseAddress, stringifyAddress, stringifyLogAddr, stringifyLogMsg
import os

UNKNOWNADDR = '"unknown"<sip:unknown@unknown.unknown:5060>'

#direction for outgoing message
EXT = 0
LOC = 1

ALLOWMETHODS = [ 'INVITE', 'ACK', 'OPTIONS', 'BYE', 'CANCEL' ] 
ALLOWEVENTS = [ 'telephone-event', 'refer']
ALLOWEXTENSIONS = []

log = logging.getLogger('gmitm')

class GMITMEventListener(object):
    """
    Implements a sample GMITM sample event sink.
    """
    
    def onCallCreated(self, cc, msg):
        """
        cc = call controller
        cid = callid
        msg = sip message
        """
        pass
    
    def onCallProgress(self, cc, msg):
        pass
    
    def onCallConnected(self, cc, msg):
        pass
    
    def onCallTerminated(self, cc, msg, code):
        """
        code = final sip code
        msg may be None in case of timeout.
        CallControler will be deleted after this event.
        """
        pass
    
    def onStartCryptoHandshake(self, cc):
        pass
    
    def onStopCryptoHandshake(self, cc):
        pass
    
    def onCryptoStateInfo(self, cc, state):
        pass
    
    def onSecureOn(self, cc, cipher, sas, verified):
        pass
    
    def onSecureOff(self, cc):
        pass
    
    def onZrtpFailed(self, cc):
        pass
    
    def onZrtpAskEnrollment(self, cc, info):
        pass

    def onZrtpInformEnrollent(self, cc, info):
        pass

    def onZrtpSignSAS(self, cc, sasHash):
        pass

    def onZrtpCheckSASSignature(self, cc, sasHash):
        return True
    
    
def equalPORT(a, b):
    return (a or consts.DEFAULTPORT) == (b or consts.DEFAULTPORT)


def equalURL(a, b):
    return (a.host == b.host) and equalPORT(a.port, b.port)


class GMITM(object):
    '''
    GOOD MAN IN THE MIDDLE:
    
    Manages the original and the rewritten phone/proxy addresses.
    All messages enter and leave here.
    Keeps track of calls (dialogs).
    Perspective of message handling is man in the middle (of UAC):
    
    +------------+                +--------+                 +-----------------------+
    | your proxy |<---your lan--->| zsipos |<---local net--->| your phone/sip-client | 
    +------------+  ("ext" side)  +--------+  ("loc" side)   +-----------------------+
          ^
          :                                                
          :
          v
    +--------------+
    | wan/internet |
    +--------------+

    Notes: 
     - There is no ip routing between your lan and the local net. 
     - Zsipos overtakes the original ip address of your phone. 
     - Your phone/sip-client must use zsipos as proxy. 
    '''
    extphoneaddr = None
    locproxyaddr = None
    extPort = None
    locPort = None

    def __init__(self):
        if config.has_option(consts.SECTION, consts.EXTPHONEADDR):
            self.extphoneaddr = config.get(consts.SECTION, consts.EXTPHONEADDR).strip()
        if config.has_option(consts.SECTION, consts.LOCPROXYADDR):
            self.locproxyaddr = config.get(consts.SECTION, consts.LOCPROXYADDR).strip()
        self.extProxyURL = parseURL("sip:" + config.get(consts.SECTION, consts.EXTPROXYADDR) + ":" + config.get(consts.SECTION, consts.EXTPROXYPORT))
        log.info("original proxy address: %s", self.extProxyURL.toString())
        self.phoneInfoValid = False
        self.locPhoneURL = parseAddress(UNKNOWNADDR)[1]
        self.extProto = SipProtocol(self.extMessageReceived)
        self.locProto = SipProtocol(self.locMessageReceived)
        self.myAddr = parseAddress(UNKNOWNADDR)
        self.locContact = UNKNOWNADDR
        self.extContact = UNKNOWNADDR
        self.callmap = { }
        self.branchmap = { }
        self.seq2branch = [ { }, { } ]
        self.dolog = [ config.getboolean(consts.SECTION, consts.LOGLOC), config.getboolean(consts.SECTION, consts.LOGEXT) ]
        self.logfull = config.getboolean(consts.SECTION, consts.LOGFULLMESSAGE)
        self.eventsink = None
        if self.extphoneaddr and len(self.extphoneaddr):
            self.extStartListening(self.extphoneaddr)
        if self.locproxyaddr and len(self.locproxyaddr):
            self.locStartListening(self.locproxyaddr)
            
    def setEventSink(self, sink):
        """
        Sets the eventsink, None to disable event notifications
        """
        self.eventsink = sink

    def initializePhoneInfo(self, msg, addr):
        if self.phoneInfoValid:
            #TODO: check if something changed!
            return
        self.myAddr = parseAddress(msg.headers['from'][0])
        self.locPhoneURL = addr
        contact = msg.headers.get('contact')
        if contact:
            self.locContact = parseAddress(contact[0])[1]
        else:
            self.locContact = self.locPhoneURL 
        self.extContact = self.extPhoneURL    
        log.info("user address: %s", self.myAddr[1].toString())
        log.info("phone address: %s", self.locPhoneURL.toString())
        log.info("phone contact: %s", self.locContact)
        #
        # TODO(adi): RFC3261: what about FQDN/address mixing?
        #
        # Initialize the transformation matrixes, from the point of view: phone --> proxy
        #
        # addresses: list of tuple (fieldname, actions : list of tuple ( searchURL, replaceURL ) ) 
        self.xfrmAddresses = \
            [
             (
              'from'   , [ (self.locPhoneURL, self.extPhoneURL) ] 
              ),
             (
              'to'     , [ (self.locPhoneURL, self.extPhoneURL) ] 
              ),
             (
              'contact', [ (self.locContact , self.extContact ),
                           (self.locProxyURL, self.extProxyURL)  ] 
              )
            ]
        # via0: list of tuple (searchURL, replaceURL)
        self.xfrmVia0 = [ 
             (self.locPhoneURL, self.extPhoneURL),
             (self.locProxyURL, self.extProxyURL) 
        ]
        # Replacement mappings for the URI of requests.
        # TODO(jojo): Is this always the same as the "xfrmVia0"?
        self.xfrmURIs = [
            (self.locPhoneURL, self.extPhoneURL),
            (self.locProxyURL, self.extProxyURL),
        ]
        self.phoneInfoValid = True
        
    def idleactions(self):
        '''
        Gets called after all calls have terminated.
        ''' 
        self.save_random_seed()
        log.debug("garbage collection")
        gc.collect()

    def isRequestToMe(self, msg):
        return msg.uri.username == self.myAddr[1].username \
            and msg.uri.host in [self.myAddr[1].host, self.extPhoneURL.host]

    def fixAddresses(self, msg, xfrmactions, destination):
        for field, actions in xfrmactions:            
            addresses = msg.headers.get(field)
            if not addresses:
                continue
            for i, addr in enumerate(addresses):
                name, uri, params = parseAddress(addr)
                for search, replace in actions:
                    if destination == LOC:
                        search, replace = replace, search
                    if equalURL(uri, search):
                        uri.host = replace.host
                        uri.port = replace.port
                        addresses[i] = stringifyAddress(name, uri, params) 
                        break # only one can match
                
    def fixVia0(self, msg, xfrmactions, destination):
        via0 = msg.via0
        for search, replace in xfrmactions:
            if destination == LOC:
                search, replace = replace, search
            if equalURL(search, via0):
                via0.transport = replace.transport or "UDP"
                via0.host      = replace.host
                via0.port      = replace.port
                if via0.received and via0.received == search.host:
                    via0.received = replace.host
                if via0.rportValue and equalPORT(via0.rportValue, search.port):
                    via0.rportValue = replace.port
                msg.headers['via'][0] = via0.toString()
                break # only one can match
            
    def fixURI(self, msg, xfrmactions, destination):
        for (search, replace) in xfrmactions:
            if destination == LOC:
                search, replace = replace, search
            if equalURL(msg.uri, search):
                msg.uri.host = replace.host
                msg.uri.port = replace.port            

    def fixOptions(self, msg):
        #TODO: build intersect
        msg.headers['allow'] = [ ",".join(ALLOWMETHODS) ]
        msg.headers['allow-events'] = [ ",".join(ALLOWEVENTS) ]
        s = msg.headers.get('supported')
        if s:
            del msg.headers['supported']
        s = msg.headers.get('methods')
        if s:
            del msg.headers['methods']
        #TODO: check for Required:, Proxy-Require: (and reject)
        
    def addZSIPOStoRoute(self, msg):
        s = msg.headers.get('record-route')
        if not s:
            return
        if isinstance(msg, Request):
            msg.headers['record-route'] = [self.locRoute] + s
        else:
            msg.headers['record-route'] = s + [self.locRoute]
        
    def delZSIPOSfromRoute1(self, msg):
        s = msg.headers.get('record-route')
        if not s:
            return
        if s[0] != self.locRoute:
            return
        if len(s) == 1:
            del msg.headers['record-route']
        else:
            msg.headers['record-route'] = s[1:]
        
    def delZSIPOSfromRoute2(self, msg):
        s = msg.headers.get('route')
        if not s:
            return
        if s[0] != self.locRoute:
            return
        if len(s) == 1:
            del msg.headers['route']
        else:
            msg.headers['route'] = s[1:]
            
    def delZSIPOSfromRoute(self, msg):
        self.delZSIPOSfromRoute1(msg)
        self.delZSIPOSfromRoute2(msg)
            
    def fixRoute(self, msg, addr):
        r = msg.headers.get('route')
        if not r:
            return addr
        ret = parseURL(r[0].split('<', 1)[1].rsplit('>', 1)[0], port=consts.DEFAULTPORT)
        if self.dolog[True]:
            log.info('send to route addr: %s', ret.toString())
        return ret
        
    def getBranch(self, msg, external):
        t = self.branchmap.get(msg.via0.branch)
        if not t and isinstance(msg, Request):
            if msg.method == 'ACK':
                t = self.seq2branch[external].get(msg.cseq[0])
            if not t:
                t = Branch(self, msg, external)
                self.branchmap[msg.via0.branch] = t
                self.seq2branch[external][msg.cseq[0]] = t
        return t
    
    def delBranch(self, branch):
        try:
            del self.branchmap[branch.branch]
        except KeyError:
            pass
        try:
            del self.seq2branch[branch.external][branch.cseq[0]]
        except KeyError:
            pass
        if len(self.branchmap) + len(self.callmap) == 0:
            self.idleactions()
    
    def logIOMesssage(self, msg, addr, received, external):
        if not self.dolog[external]:
            return
        s =  ["l"  , "e"  ][external] 
        s += ["->" , "<-" ][received]
        s += stringifyLogAddr(addr)
        s += stringifyLogMsg(msg, self.logfull)
        log.info(s)

    def extMessageReceived(self, msg, addr):
        self.logIOMesssage(msg, addr, received = True, external = True)
        branch = self.getBranch(msg, external = True)
        if branch:
            branch.messageReceived(msg, addr, external = True)
            return
        self.messageReceived(msg, addr, external = True)
                            
    def locMessageReceived(self, msg, addr):
        self.logIOMesssage(msg, addr, received = True, external = False)
        branch = self.getBranch(msg, external = False)
        if branch:
            branch.messageReceived(msg, addr, external = False)
            return
        self.messageReceived(msg, addr, external = False)
            
    def extSendMessage(self, addr, msg):
        '''
        Send a message to the external interface ("Proxy").
        Masquerade phone/proxy.
        '''
        # TODO: multicast
        self.fixAddresses(msg, self.xfrmAddresses, destination = EXT)
        self.fixVia0(msg, self.xfrmVia0, destination = EXT)
        if isinstance(msg, Request):
            self.fixURI(msg, self.xfrmURIs, destination = EXT)
        self.delZSIPOSfromRoute(msg)
        addr = self.fixRoute(msg, addr)
        self.logIOMesssage(msg, addr, received = False, external = True)
        return (self.extProto.sendMessage(addr, msg), addr)
    
    def locSendMessage(self, addr, msg):
        '''
        Send a message to the internal interface ("Phone").
        Demasquerade phone/proxy.
        '''
        self.fixAddresses(msg, self.xfrmAddresses, destination = LOC)
        self.fixVia0(msg, self.xfrmVia0, destination = LOC)
        if isinstance(msg, Request):
            self.fixURI(msg, self.xfrmURIs, destination = LOC)
        self.addZSIPOStoRoute(msg)
        self.logIOMesssage(msg, addr, received = False, external = False)
        return (self.locProto.sendMessage(addr, msg), addr)
    
    def extSendRawData(self, addr, data):
        self.extProto.sendRawData(addr, data)
        
    def locSendRawData(self, addr, data):
        self.locProto.sendRawData(addr, data)
    
    def extStartListening(self, addr):
        self.extPhoneURL = parseURL("sip:" + addr + ":" + config.get(consts.SECTION, consts.EXTPHONEPORT))
        log.info("original phone address: %s", self.extPhoneURL.toString())
        self.extPort = reactor.listenUDP(self.extPhoneURL.port, self.extProto, interface = self.extPhoneURL.host)  # @UndefinedVariable

    def locStartListening(self, addr):
        self.locProxyURL = parseURL("sip:" + addr + ":" + config.get(consts.SECTION, consts.LOCPROXYPORT))
        self.locRoute = '<' + self.locProxyURL.toString() + ';lr>'
        log.info("proxy address for phone: %s", self.locProxyURL.toString())
        self.locPort = reactor.listenUDP(self.locProxyURL.port, self.locProto, interface = self.locProxyURL.host)  # @UndefinedVariable

    def extStopListening(self):
        if self.extPort:
            self.extPort.stopListening()
            self.extPort = None
            
    def locStopListening(self):
        if self.locPort:
            self.locPort.stopListening()
            self.locPort = None
            
    def messageReceived(self, msg, addr, external):
        if isinstance(msg, Request):
            return self.handle_request(msg, addr, external)
        else:
            return self.handle_response(msg, addr, external)
        
    def forwardMessage(self, msg, external):
        if external:
            return self.locSendMessage(self.locPhoneURL, msg)
        else:
            return self.extSendMessage(self.extProxyURL, msg)
        
    def forwardRawData(self, data, addr, external):
        if external:
            self.locSendRawData(addr, data)
        else:
            self.extSendRawData(addr, data)
            
    def badMessage(self, msg, comment):
        log.error(comment)
        log.error(msg.toString())
        
    def checkPhoneInfoValid(self):
        if not self.phoneInfoValid:
            log.info("phone still not recognized - message ignored.")
        return self.phoneInfoValid
        
    def handle_request(self, msg, addr, external):
        cc = self.callmap.get(msg.cid)
        self.fixOptions(msg)
        if external:
            if not self.checkPhoneInfoValid():
                return None
            if self.isRequestToMe(msg):
                if msg.method == 'INVITE':
                    if not cc:
                        cc = CallController(self, msg, incoming = True)
                        self.callmap[msg.cid] = cc
            else:
                self.badMessage(msg, "warning: request is not to me")
        else:
            if msg.method == 'REGISTER':
                self.initializePhoneInfo(msg, addr)
            elif msg.method == 'INVITE':
                self.initializePhoneInfo(msg, addr)
                if not cc:
                    cc = CallController(self, msg, incoming = False)
                    self.callmap[msg.cid] = cc
            elif not self.checkPhoneInfoValid():
                return None
        if cc:
            return cc.handle_request(msg, external)
        return self.forwardMessage(msg, external)
    
    def handle_response(self, msg, addr, external):
        if not self.checkPhoneInfoValid():
            return None
        cc = self.callmap.get(msg.cid)
        self.fixOptions(msg)
        if cc:
            return cc.handle_response(msg, external)
        return self.forwardMessage(msg, external)

    def save_random_seed(self):
        call = "dd if=/dev/urandom of=/etc/random-seed count=1 2>/dev/null"
        os.system(call)
        os.system('sync')

    # cc callbacks
        
    def on_call_created(self, cc, msg):
        if not self.eventsink: return
        self.eventsink.onCallCreated(cc, msg)
            
    def on_call_progress(self, cc, msg):
        if not self.eventsink: return
        self.eventsink.onCallProgress(cc, msg)

    def on_call_connected(self, cc, msg):
        if not self.eventsink: return
        self.eventsink.onCallConnected(cc, msg)
            
    def on_call_terminated(self, cc, msg, code):
        del self.callmap[cc.cid]
        cc.close()
        log.debug("active calls=%d", len(self.callmap))
        if not self.eventsink: return
        self.eventsink.onCallTerminated(cc, msg, code)
        
    # crypto callbacks

    def on_start_crypto_handshake(self, cc):
        if not self.eventsink: return
        self.eventsink.onStartCryptoHandshake(cc)
    
    def on_stop_crypto_handshake(self, cc):
        if not self.eventsink: return
        self.eventsink.onStopCryptoHandshake(cc)
        
    def on_crypto_state_info(self, cc, status):
        if not self.eventsink: return
        self.eventsink.onCryptoStateInfo(cc, status)
    
    def on_secure_on(self, cc, cipher, sas, verified):
        if not self.eventsink: return
        self.eventsink.onSecureOn(cc, cipher, sas, verified)
    
    def on_secure_off(self, cc):
        if not self.eventsink: return
        self.eventsink.onSecureOff(cc)
    
    def on_zrtp_failed(self, cc):
        if not self.eventsink: return
        self.eventsink.onZrtpFailed(cc)

    def on_zrtp_ask_enrollment(self, cc, info):
        if not self.eventsink:
            cc.acceptEnrollment(True) 
            return
        self.eventsink.onZrtpAskEnrollment(cc, info)

    def on_zrtp_inform_enrollent(self, cc, info):
        if not self.eventsink: return
        self.eventsink.onZrtpInformEnrollent(cc, info)

    def on_zrtp_sign_sas(self, cc, sasHash):
        if not self.eventsink:
            cc.setSASVerified() 
            return
        self.eventsink.onZrtpSignSAS(cc, sasHash)

    def on_zrtp_check_sas_signature(self, cc, sasHash):
        if not self.eventsink: return False
        return self.eventsink.onZrtpCheckSASSignature(cc, sasHash)
    