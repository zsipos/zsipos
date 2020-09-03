# SPDX-FileCopyrightText: 2019 Stefan Adams <stefan.adams@vipcomag.de>
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

cdef class CyRTPStream

cdef class CyZRTPSession:

    cdef pj_pool_t*    pool
    cdef pj_ioqueue_t* ioq

    cdef object      cc
    cdef CyRTPStream stream
    cdef string      zidfilename
    cdef bool        logcb

    def __init__(self, cc, zidfilename):
        global g
        self.cc = cc
        self.zidfilename = zidfilename
        self.logcb = config.getboolean(consts.SECTION, consts.LOGZSESSIONCB)
        self.pool = pj_pool_create(&g.caching_pool.factory, "zrtpsession_pool", 0, (MAXRTPLEN+20)*SOCKS1CALL, NULL)
        if not self.pool:
            pj_raise_exception(PJ_ENOMEM)
        self.ioq = g.rtp_ioq
        self.stream = CyRTPStream(self, cc.get_is_incoming())

    def __dealloc__(self):
        self.close()
        if self.pool:
            pj_pool_release(self.pool)

    def close(self):
        if self.stream:
            self.stream.close()
            
    def getExtHost(self):
        return self.cc.gmitm.extPhoneURL.host
    
    def getLocHost(self):
        return self.cc.gmitm.locProxyURL.host
            
    def extGetAddress(self):
        return self.stream.extGetAddress()
    
    def extGetCtrlAddress(self):
        return self.stream.extGetCtrlAddress()
    
    def locGetAddress(self):
        return self.stream.locGetAddress()
    
    def locGetCtrlAddress(self):
        return self.stream.locGetCtrlAddress()
    
    def extSetDstAddress(self, addr):
        return self.stream.extSetDstAddress(addr)
    
    def extSetDstCtrlAddress(self, addr):
        return self.stream.extSetDstCtrlAddress(addr)
    
    def locSetDstAddress(self, addr):
        return self.stream.locSetDstAddress(addr)
    
    def locSetDstCtrlAddress(self, addr):
        return self.stream.locSetDstCtrlAddress(addr)
    
    def setAudioInfo(self, audioinfo):
        return self.stream.setAudioInfo(audioinfo)
    
    def addressesReady(self):
        self.stream.addressesReady()
    
    def goSecure(self):
        self.stream.goSecure()
        
    def setSASVerified(self):
        self.stream.setSASVerified()
    
    def resetSASVerified(self):
        self.stream.resetSASVerified()
        
    def acceptEnrollment(self, accepted):
        self.stream.acceptEnrollment(accepted)
        
    def get_is_handshake(self):
        return self.stream.get_is_handshake()
    
    def getStatus(self):
        return self.stream.getStatus()
        
    cdef void configureZrtp(self, CyRTPStream stream) nogil:
        zrtp.zrtp_InitializeConfig(stream.zcontext)
        zrtp.zrtp_setMandatoryOnly(stream.zcontext)
        zrtp.zrtp_addAlgoAt(stream.zcontext, zrtp.zrtp_PubKeyAlgorithm, "EC25", 0)
        zrtp.zrtp_addAlgoAt(stream.zcontext, zrtp.zrtp_PubKeyAlgorithm, "EC38", 1)
        zrtp.zrtp_initializeZrtpEngine(stream.zcontext, &callbacks, "zsipos", self.zidfilename.c_str(), <void*>stream, False)
    
#
# user callbacks
#

    cdef void startCryptoHandshake(self, CyRTPStream stream) with gil:
        if self.logcb: logs.debug("startCryptoHandshake")
        self.cc.on_start_crypto_handshake()

    cdef void stopCryptoHandshake(self, CyRTPStream stream) with gil:
        if self.logcb: logs.debug("stopCryptoHandshake")
        self.cc.on_stop_crypto_handshake()
        
    cdef void cryptoStateInfo(self, CyRTPStream stream, int state) with gil:
        if self.logcb: logs.debug("cryptoStateInfo")
        self.cc.on_crypto_state_info(state)
        
    cdef void secureOn(self, CyRTPStream stream, object cipher, object sas, bool verified) with gil:
        if self.logcb: logs.debug("secureOn: cipher=%s, sas=%s, verified=%d", cipher, sas, verified)
        self.cc.on_secure_on(cipher, sas, verified) 

    cdef void secureOff(self, CyRTPStream stream) with gil:
        if self.logcb: logs.debug("secureOff")
        self.cc.on_secure_off()

    cdef void handleGoClear(self, CyRTPStream stream) with gil:
        if self.logcb: logs.debug("handleGoClear")
        logs.error("go clear not implemented.")

    cdef void showMessage(self, CyRTPStream stream, int32_t severity, int32_t subCode) with gil:
        if self.logcb:
            str1 = zrtp_MessageSeverity_names[severity]
            str2 = zrtp_SeveritySubCode_names[severity][abs(subCode)]
            logs.debug("showMessage: severity=(%d) %s, subCode=(%d) %s", severity, str1, subCode, str2)
        #self.cc.on_show_message(severity, subcode)

    cdef void zrtpNegotiationFailed(self, CyRTPStream stream, int32_t severity, int32_t subCode) with gil:
        if self.logcb:
            str1 = zrtp_MessageSeverity_names[severity]
            str2 = zrtp_SeveritySubCode_names[severity][abs(subCode)]
            logs.debug("zrtpNegotiationFailed: severity=(%d) %s, subCode=(%d) %s", severity, str1, subCode, str2)
        self.cc.on_zrtp_failed()

    cdef void zrtpNotSuppOther(self, CyRTPStream stream) with gil:
        if self.logcb: logs.debug("zrtpNotSuppOther")
        self.cc.on_zrtp_failed()

    cdef void zrtpAskEnrollment(self, CyRTPStream stream, int32_t info) with gil:
        if self.logcb:
            str1 = zrtp_InfoEnrollment_names[info]
            logs.debug("zrtpAskEnrollment: info=(%d) %s", info, str1)
        self.cc.on_zrtp_ask_enrollment(info)

    cdef void zrtpInformEnrollment(self, CyRTPStream stream, int32_t info) with gil:
        if self.logcb:
            str1 = zrtp_InfoEnrollment_names[info]
            logs.debug("zrtpInfoEnrollment: info=(%d) %s", info, str1)
        self.cc.on_zrtp_inform_enrollent(info)

    cdef void signSAS(self, CyRTPStream stream, uint8_t* sasHash) with gil:
        if self.logcb: logs.debug("signSAS")
        self.cc.on_zrtp_sign_sas(sasHash[:31])

    cdef bool checkSASSignature(self, CyRTPStream stream, uint8_t* sasHash) with gil:
        if self.logcb: logs.debug("checkSASSignature")
        return self.cc.on_zrtp_check_sas_signature(sasHash[:31])

