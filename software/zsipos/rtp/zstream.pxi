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


cdef bool globalMute = False

def setGlobalMute(on):
    global globalMute
    globalMute = on

def getGlobalMute():
    return globalMute
    
cdef extern from "../alawulaw.tables":
    cdef pj_uint8_t zsipos_a2u[]
    cdef pj_uint8_t zsipos_u2a[]
    cdef pj_uint8_t zsipos_alaw0
    cdef pj_uint8_t zsipos_ulaw0

cdef zrtp.zrtp_Callbacks callbacks

cdef class MyDTMFExchange(DTMFExchange)
cdef class MyICEStream(PJICEStream)

cdef uint64_t pjtime2ms(pj_time_val* tv) nogil:
    return (<uint64_t>tv.sec * 1000 + tv.msec)
        
class StreamStatus(object):
    pass

cdef class CyRTPStream:
    """
    All messages for one rtp stream pass this object.
    
    direct message flow:
    --------------------
    extDataReceived -> (zrtp decode) -> locSendData
    locDataReceived -> (zrtp encode) -> extSendData
    
    ice based message flow:
    -----------------------
    iceDataReceived -> (zrtp decode) -> locSendData
    locDataReceived -> (zrtp encode) -> iceSendData
    """
    
    #IPC
    cdef pj_event_t* created_event
    cdef object      created_exception
    cdef pj_event_t* deleted_event
    
    #RTP
    #local
    cdef PJUDPSock   locsock
    cdef PJUDPSock   locsockctrl
    cdef pj_sockaddr locdstaddr
    cdef int         locdstaddr_len
    cdef pj_sockaddr locdstaddrctrl
    cdef int         locdstaddrctrl_len
    cdef uint16_t    locseq
    cdef uint32_t    loctimestamp
    cdef int16_t     locoffset
    cdef pj_time_val loctime
    #extern
    cdef PJUDPSock   extsock
    cdef PJUDPSock   extsockctrl
    cdef pj_sockaddr extdstaddr
    cdef int         extdstaddr_len
    cdef pj_sockaddr extdstaddrctrl
    cdef int         extdstaddrctrl_len
#    cdef uint16_t    extseq
#    cdef uint32_t    exttimestamp
#    cdef uint32_t    extoffset

    cdef AUDIOINFO   audioinfo
    cdef bool        fmtwarningpcma    
    cdef bool        fmtwarningpcmu    
    cdef bool        addrsready
    cdef bool        handshake
    cdef bool        isIncoming
    
    cdef uint32_t    nrlocin
    cdef uint32_t    nrlocout
    cdef uint32_t    nrextin
    cdef uint32_t    nrextout

    #keepalive
    cdef pj_timer_entry keepalive_timer
    cdef pj_uint8_t*    keepalive_packet
    cdef pj_size_t      keepalive_packet_len
    
    #DTMF
    cdef MyDTMFExchange dtmfex
    
    #ICE
    cdef bool           remote_started_ice
    cdef bool           logice
    cdef IceStates      ice_state
    cdef MyICEStream    icestream       
    cdef uint32_t       nricein
    cdef uint32_t       nriceout
    
    
    #ZRTP 
    cdef CyZRTPSession       zsession
    cdef zrtp.ZrtpContext*   zcontext
    cdef pj_event_t*         zrtp_start_event
    cdef pj_event_t*         zrtp_stop_event
    cdef pj_lock_t*          zrtp_lock
    cdef pj_timer_entry      zrtp_timer
    cdef bool                logcb
    cdef bool                logsecrets
    cdef ZrtpStates          zrtp_state
    cdef bool                secure
    cdef bool                verified
    cdef bool                needsflush
    cdef int32_t             failed_severity
    cdef int32_t             failed_subcode
    cdef object              received_cipher
    cdef object              received_sas
    cdef uint32_t            extSSRC
    cdef uint32_t            locSSRC
    cdef uint16_t            senderZrtpSeqNo
    cdef srtp.CryptoContext* sendCtx
    cdef srtp.CryptoContext* sendCtxCtrl
    cdef srtp.CryptoContext* recvCtx
    cdef srtp.CryptoContext* recvCtxCtrl
    cdef uint32_t            nrunprotectedin
    cdef uint32_t            nrprotectedin
    cdef uint32_t            nrdecodefailed
    cdef uint32_t            nrunprotectedout
    cdef uint32_t            nrprotectedout
    
    def __init__(self, zrtpsession, isIncoming):
        cdef pj_status_t
        self.zsession = zrtpsession
        self.isIncoming = isIncoming
        self.logice = config.getboolean(consts.SECTION, consts.LOGICE)
        self.logcb = config.getboolean(consts.SECTION, consts.LOGZRTPCB)
        self.logsecrets = False # WARNING: debug only! crypto keys on python heap!
        status = pj_event_create(self.zsession.pool, "created_event", PJ_FALSE, PJ_FALSE, &self.created_event)
        pj_check_status(status)
        status = pj_event_create(self.zsession.pool, "deleted_event", PJ_FALSE, PJ_FALSE, &self.deleted_event)
        pj_check_status(status)

        status = self.callOnThread(RTP_THREAD, <mq_handler_t>self.do_create, NULL)
        pj_check_status(status)
        with nogil: pj_event_wait(self.created_event)
        if self.created_exception: raise(self.created_exception)
        
    cdef void do_create(self, MQCBDATA *cbdata) with gil:
        try:
            status = pj_event_create(self.zsession.pool, "zrtp_start_event", PJ_FALSE, PJ_FALSE, &self.zrtp_start_event)
            pj_check_status(status)
            status = pj_event_create(self.zsession.pool, "zrtp_stop_event", PJ_FALSE, PJ_FALSE, &self.zrtp_stop_event)
            pj_check_status(status)
            status = pj_lock_create_simple_mutex(self.zsession.pool, "zrtp_lock", &self.zrtp_lock)
            pj_check_status(status)
            pj_timer_entry_init(&self.zrtp_timer, 0, <void*>self, CyRTPStream_zrtp_timedout)
            self.zrtp_state = ZRTP_STATE_NONE
            zrtp.zrtp_getRandomData(<uint8_t*>&self.senderZrtpSeqNo, sizeof(uint16_t))
            self.senderZrtpSeqNo &= 0x7fff
            self.ice_state = ICE_STATE_NONE
            pj_timer_entry_init(&self.keepalive_timer, 0, <void*>self, CyRTPStream_keepalive_timedout)
            self._sockalloc(False)
            self._sockalloc(True)
            logz.debug("%d timers registered on create", pj_timer_heap_count(g.rtp_timer_heap))
        except Exception as e:
            logz.error("%s", e, exc_info = exc_info())
            self.created_exception = e
        with nogil: 
            pj_event_set(self.created_event)
            return
        
    def __dealloc__(self):
        self.close()
        
    def close(self):
        with nogil:
            if self.deleted_event: 
                if self.callOnThread(RTP_THREAD, <mq_handler_t>self.do_close, NULL) == PJ_SUCCESS:
                    pj_event_wait(self.deleted_event)
                pj_event_destroy(self.deleted_event)
                self.deleted_event = NULL 
            if self.created_event:
                pj_event_destroy(self.created_event)
                self.created_event = NULL    
        
    cdef void do_close(self) with gil:
        global g
        try:
            self.stopDTMF()
            if self.locsock:
                logz.debug("local packakges in: %d", self.nrlocin)
                logz.debug("local packages out: %d", self.nrlocout)
                logz.debug("external packakges in: %d", self.nrextin)
                logz.debug("external packages out: %d", self.nrextout)
                logz.debug("ice packakges in: %d", self.nricein)
                logz.debug("ice packages out: %d", self.nriceout)
                logz.debug("unprotected packages in : %d", self.nrunprotectedin)
                logz.debug("unprotected packages out: %d", self.nrunprotectedout)
                logz.debug("protected packages in : %d", self.nrprotectedin)
                logz.debug("protected packages out: %d", self.nrprotectedout)
                logz.debug("failed package decodes: %d", self.nrdecodefailed)
                logz.debug("%d timers registered on delete", pj_timer_heap_count(g.rtp_timer_heap))
                #pj_timer_heap_dump(g.rtp_timer_heap)
            pj_timer_heap_cancel(g.zrtp_timer_heap, &self.zrtp_timer)
            if self.zcontext:
                with nogil: 
                    self.stopZrtp()
                    pj_event_wait(self.zrtp_stop_event)
            if self.sendCtx:
                del self.sendCtx
                self.sendCtx = NULL
            if self.sendCtxCtrl:
                del self.sendCtxCtrl
                self.sendCtxCtrl = NULL
            if self.recvCtx:
                del self.recvCtx
                self.recvCtx = NULL
            if self.recvCtxCtrl:
                del self.recvCtxCtrl
                self.recvCtxCtrl = NULL
            if self.zrtp_lock:
                pj_lock_destroy(self.zrtp_lock)
                self.zrtp_lock = NULL
            if self.icestream:
                self.icestream.close()
                self.icestream = None
            if self.extsock:
                self.extsock.close()
                self.extsock = None
            if self.extsockctrl:
                self.extsockctrl.close()
                self.extsockctrl = None
            if self.locsock:
                self.locsock.close()
                self.locsock = None
            if self.locsockctrl:
                self.locsockctrl.close()
                self.locsockctrl = None
            if self.zrtp_start_event:
                pj_event_destroy(self.zrtp_start_event)
                self.zrtp_start_event = NULL
            if self.zrtp_stop_event:
                pj_event_destroy(self.zrtp_stop_event)
                self.zrtp_stop_event = NULL
            pj_timer_heap_cancel(g.rtp_timer_heap, &self.keepalive_timer)
            if self.keepalive_packet:
                free(self.keepalive_packet)
                self.keepalive_packet = NULL
        finally:
            with nogil:
                if self.deleted_event:
                    pj_event_set(self.deleted_event)
                return
        
    def get_pool(self):
        return get_pool(self.zsession.pool)
    
    def get_ioq(self):
        return get_ioq(self.zsession.ioq)
            
    def _sockalloc(self, external):
        start = 20000
        stop  = 20100
        if external:
            host = self.zsession.getExtHost()
        else:
            host = self.zsession.getLocHost()
        for port in xrange(start, stop, 2):
            try:
                addr1 = (host, port)
                addr2 = (host, port+1)
                if external:
                    self.extsock = PJUDPSock(self.get_pool(), self.get_ioq(), addr1, qos_type = PJ_QOS_TYPE_VOICE)
                    self.extsock.setRcvCallback(<pjDatagramRcvCallback>self.extDataReceived, <void*>self)
                    self.extsockctrl = PJUDPSock(self.get_pool(), self.get_ioq(), addr2, qos_type = PJ_QOS_TYPE_CONTROL)
                    self.extsockctrl.setRcvCallback(<pjDatagramRcvCallback>self.extCtrlDataReceived, <void*>self)
                else:
                    self.locsock = PJUDPSock(self.get_pool(), self.get_ioq(), addr1, protocol = udpprotocol(True), qos_type = PJ_QOS_TYPE_VOICE)
                    self.locsock.setRcvCallback(<pjDatagramRcvCallback>self.locDataReceived, <void*>self)
                    self.locsockctrl = PJUDPSock(self.get_pool(), self.get_ioq(), addr2, protocol = udpprotocol(True), qos_type = PJ_QOS_TYPE_CONTROL)
                    self.locsockctrl.setRcvCallback(<pjDatagramRcvCallback>self.locCtrlDataReceived, <void*>self)
                return
            except RTPException as e:
                if e.code == PJ_STATUS_FROM_OS(EADDRINUSE):
                    if external:
                        if self.extsock:
                            self.extsock.close()
                            self.extsock = None
                    else:
                        if self.locsock:
                            self.locsock.close()
                            self.locsock = None
                    continue
                raise e
        raise Exception("can not find free port")
    
    #
    # input/output addresses
    #
    
    def extGetAddress(self):
        return self.extsock.getsockname()
    
    def extGetCtrlAddress(self):
        return self.extsockctrl.getsockname()
    
    def locGetAddress(self):
        return self.locsock.getsockname()
    
    def locGetCtrlAddress(self):
        return self.locsockctrl.getsockname()
    
    cdef void set_addr(self, pj_sockaddr* paddr, int *len, addr) except *:
        cdef pj_str_t tmpstr
        cdef pj_status_t
        pj_cstr(&tmpstr, addr[0])
        status = pj_sockaddr_init(pj_AF_INET(), paddr, &tmpstr, addr[1])
        pj_check_status(status)
        len[0] = pj_sockaddr_get_len(paddr)
    
    def extSetDstAddress(self, addr):
        def ___():
            self.set_addr(&self.extdstaddr, &self.extdstaddr_len, addr)
        callRTP(___)
        
    def extSetDstCtrlAddress(self, addr):
        def ___():
            self.set_addr(&self.extdstaddrctrl, &self.extdstaddrctrl_len, addr)
        callRTP(___)
        
    def locSetDstAddress(self, addr):
        def ___():
            self.set_addr(&self.locdstaddr, &self.locdstaddr_len, addr)
        callRTP(___)
        
    def locSetDstCtrlAddress(self, addr):
        def ___():
            self.set_addr(&self.locdstaddrctrl, &self.locdstaddrctrl_len, addr)
        callRTP(___)
        
    def setAudioInfo(self, audioinfo):
        def ___():
            cdef AUDIOINFO *h = &self.audioinfo
            h.rate, h.ptime, h.pcmu, h.pt = audioinfo
            h.ticks1ms = h.rate // 1000
        log.debug("audioinfo: %s", audioinfo)
        self.keepalive_packet_len = audioinfo[0] * audioinfo[1] // 1000 + zrtp.RTP_HEADER_LENGTH
        self.keepalive_packet = <uint8_t*>malloc(self.keepalive_packet_len)
        if not self.keepalive_packet:
            pj_check_status(PJ_ENOMEM)
        self.keepalive_packet[0] = 0x80 # V2
        if audioinfo[2]: 
            self.keepalive_packet[1] = 0x80 # M + PCMU payload          
        else: 
            self.keepalive_packet[1] = 0x88 # M + PCMA payload          
        for i in xrange(2, self.keepalive_packet_len):
            self.keepalive_packet[i] = i % 256
        callRTP(___)
        
    #
    # zrtp control interface, called from python
    #
    
    def addressesReady(self):
        def ___():
            self.addrsready = True
            self.zsession.cryptoStateInfo(self, CRYPTO_STATEINFO_NONE)
        callRTP(___)
    
    def goSecure(self):
        cdef bool skipzrtp1
        cdef bool started
        skipzrtp1 = config.getboolean(consts.SECTION, consts.SKIPZRTP1)
        with nogil:
            if skipzrtp1:
                started = self.startICE()
            else: 
                started = self.startZrtp()
        if not started:
            raise Exception("can not start zrtp engine")
        
    cdef void setSASVerified(self) nogil:
        self.verified = True
        zrtp.zrtp_SASVerified(self.zcontext)
    
    cdef void resetSASVerified(self) nogil:
        self.verified = False
        zrtp.zrtp_resetSASVerified(self.zcontext)
        
    cdef void acceptEnrollment(self, bool accepted) nogil:
        zrtp.zrtp_acceptEnrollment(self.zcontext, accepted)
        
    cdef bool get_is_handshake(self):
        return self.handshake
        
    def getStatus(self):
        ret = StreamStatus()
        d = ret.__dict__
        d["isincoming"] = self.isIncoming
        d["secure"] = self.secure 
        d["handshake"] = self.handshake
        d["ice_state"] = self.ice_state
        d["zrtp_state"] = self.zrtp_state
        if self.secure:
            d["cipher"] = self.received_cipher
            d["sas"] = self.received_sas
            d["verified"] = self.verified
        else:
            d["cipher"] = None
            d["sas"] = None
            d["verified"] = None
        if self.failed_severity:
            d["failed"] = (self.failed_severity, self.failed_subcode)
        else:
            d["failed"] = None
        return ret
    
    #
    # Time critical methods. Avoid calls to python if possible.
    # If you have to call python remeber the GIL.
    #
    
    cdef hexstr(self, const uint8_t *data, int length) with gil:
        ret = "(" + str(length) + ")"
        for i in xrange(0, length):
            ret += "%02x" % (int(data[i]))
        return ret
        
    #       
    # RTP
    #
    
    cdef void flush(self) nogil:
        self.needsflush = False
        self.extsock.flush()
        self.locsock.flush()
        if self.ice_state == ICE_STATE_CONNECTED:
            self.icestream.flush()
    
    cdef void extDataReceived(self, const pj_sockaddr_t* addr, int addrlen, pj_uint8_t* databuf, pj_size_t datalen) nogil:
        self.nrextin += 1
        if self.audioinfo.pt and databuf[1] == (0x80 | self.audioinfo.pt) and datalen == 16:
            if self.handleDTMF(databuf):
                return
        if self.needsflush:
            self.flush()
            return
        if self.ice_state == ICE_STATE_NONE or self.ice_state == ICE_STATE_FAILED:
            self.cryptDataReceived(databuf, datalen)
        
    cdef void locDataReceived(self, const pj_sockaddr_t* addr, int addrlen, pj_uint8_t* databuf, pj_size_t datalen) nogil:
        self.nrlocin += 1
        if self.needsflush:
            self.flush()
            return
        #
        # get timestamp and sequence
        #
        self.locseq = pj_ntohs((<uint16_t*>&databuf[2])[0])
        self.loctimestamp = pj_ntohl((<uint32_t*>&databuf[4])[0])
        self.locSSRC = pj_ntohl((<uint32_t*>&databuf[8])[0])
        pj_gettimeofday(&self.loctime)                    
        if self.handshake:
            return
        if globalMute:
            return
        # fix in offset
        (<uint16_t*>databuf)[1] = pj_htons(self.locseq + self.locoffset)
        self.cryptDataSend(databuf, datalen)
        
    cdef void extSendData(self, pj_uint8_t* databuf, pj_size_t datalen) nogil:
        self.nrextout += 1
        if not self.addrsready: return
        self.extsock.sendData(<pj_sockaddr_t*>&self.extdstaddr, self.extdstaddr_len, databuf, datalen)
        
    cdef void locSendData(self, pj_uint8_t* databuf, pj_size_t datalen) nogil:
        self.nrlocout += 1
        if not self.addrsready: return
        self.locsock.sendData(<pj_sockaddr_t*>&self.locdstaddr, self.locdstaddr_len, databuf, datalen)
        
    cdef void iceDataReceived(self, const pj_sockaddr_t* addr, int addrlen, pj_uint8_t* databuf, pj_size_t datalen) nogil:
        # do not process anything until connected
        if self.ice_state != ICE_STATE_CONNECTED:
            return 
        self.nricein += 1
        if self.needsflush:
            self.flush()
            return
        self.cryptDataReceived(databuf, datalen)

    cdef void iceSendData(self, pj_uint8_t* databuf, pj_size_t datalen) nogil:
        # do not send anything until connected
        if self.ice_state != ICE_STATE_CONNECTED:
            return   
        self.nriceout += 1
        self.icestream.sendData(COMPID_RTP, databuf, datalen)
        
    cdef void sendData(self, pj_uint8_t* databuf, pj_size_t datalen) nogil:
        if self.ice_state == ICE_STATE_CONNECTED:
            self.iceSendData(databuf, datalen)
        elif self.ice_state == ICE_STATE_NONE or self.ice_state == ICE_STATE_FAILED:
            self.extSendData(databuf, datalen)
        
    #
    # Helpers to call callback on specific thread
    #
    cdef pj_status_t callOnThread(self, int threadid, mq_handler_t func, MQCBDATA *data) nogil:
        global g
        if threadid == RTP_THREAD:
            return mq_call(g.rtp_mq, func, <void*>self, data)
        else:
            return mq_call(g.zrtp_mq, func, <void*>self, data)
                    
    #
    # ZRTP / crypt handling (RTP)
    #
    
    cdef void fixAudioEncoding(self, pj_uint8_t* databuf, pj_size_t datalen, bool dstpcmu) nogil:
        cdef pj_uint8_t payload = databuf[1] & 0x7f
        if payload != 0x00 and payload != 0x08:
            return
        if (payload == 0x00) == dstpcmu:
            return
        cdef pj_size_t i
        if dstpcmu:
            databuf[1] = (databuf[1] & 0x80) | 0x00 # set payload to PCMU
            for i from zrtp.RTP_HEADER_LENGTH <= i < datalen:
                databuf[i] = zsipos_a2u[databuf[i]]
        else:
            databuf[1] = (databuf[1] & 0x80) | 0x08 # set payload to PCMA
            for i from zrtp.RTP_HEADER_LENGTH <= i < datalen:
                databuf[i] = zsipos_u2a[databuf[i]]     
    
    cdef void cryptDataReceived(self, pj_uint8_t* databuf, pj_size_t datalen) nogil:
        cdef int res
        # care of pending data ..
        if databuf[0] & 0xf0 != 0x10:
            # normal rtp packet
            if self.handshake:
                return
            if self.recvCtx:
                res = srtp.unprotect(self.recvCtx, databuf, datalen, &datalen, NULL)
                if res != 1:
                    # no warning - too many output if packet doubling
                    self.nrdecodefailed += 1
                    return
                # Got a good SRTP, check state and if in WaitConfAck (an Initiator state)
                # then simulate a conf2Ack, refer to RFC 6189, chapter 4.6, last paragraph
                if self.zcontext and zrtp.zrtp_inState(self.zcontext, zrtp.WaitConfAck): 
                    zrtp.zrtp_conf2AckSecure(self.zcontext)
                self.nrprotectedin += 1
            else:
                self.nrunprotectedin += 1
            self.fixAudioEncoding(databuf, datalen, self.audioinfo.pcmu)
            self.locSendData(databuf, datalen)
            return
        # from here on it maybe a zrtp packet
        if self.zrtp_state == ZRTP_STATE_NONE:
            self.startZrtp()
        cdef uint32_t ssrc = pj_ntohl((<uint32_t*>&databuf[8])[0])
        if ssrc != self.extSSRC:
            self.extSSRC = ssrc
        cdef MQCBDATA cbdata
        pj_memset(&cbdata, 0, sizeof(cbdata))
        cbdata.ssrc = ssrc
        cbdata.datalen = datalen
        cbdata.databuf = <pj_uint8_t*>malloc(datalen)
        if not cbdata.databuf:
            clog("zstream", 1, "out of memory")
            return
        memcpy(cbdata.databuf, databuf, datalen)
        if self.callOnThread(ZRTP_THREAD, <mq_handler_t>self.zrtp_HandleInput, &cbdata) != PJ_SUCCESS:
            free(cbdata.databuf)
            clog("zstream", 1, "out of memory")
            return
        
    # ... continues here, on zrtp thread

    cdef void zrtp_HandleInput(self, MQCBDATA *cbdata) nogil:
        if not <void*>self.zcontext:
            with gil: logz.warning("ZRTP old input packet...")
            free(cbdata.databuf)
            return
        if cbdata.datalen < zrtp.RTP_HEADER_LENGTH + sizeof(zrtp.HelloAckPacket_t):
            with gil: logz.warning("ZRTP packet too small")
            free(cbdata.databuf)
            return
        cdef uint32_t crc = pj_ntohl((<uint32_t*>&cbdata.databuf[cbdata.datalen-4])[0])
        if not zrtp.zrtp_CheckCksum(cbdata.databuf, cbdata.datalen-4, crc):
            self.zsession.showMessage(self, zrtp.zrtp_Warning, zrtp.zrtp_WarningCRCmismatch)
            with gil: logz.warning("ZRTP packet bad crc")
            free(cbdata.databuf)
            return
        if pj_ntohl((<uint32_t*>&cbdata.databuf[4])[0]) != zrtp.ZRTP_MAGIC:
            with gil: logz.warning("ZRTP packet bad magic")
            free(cbdata.databuf)
            return
        # from here we assume it is a zrtp packet        
        # TODO: cover the case if the other party sends _only_ ZRTP packets at the
        #      beginning of a session. Start ZRTP in this case as well.
        zrtp.zrtp_processZrtpMessage(self.zcontext, &cbdata.databuf[zrtp.RTP_HEADER_LENGTH], cbdata.ssrc, cbdata.datalen)
        free(cbdata.databuf)
    
    cdef void cryptDataSend(self, pj_uint8_t* databuf, pj_size_t datalen) nogil:
        if self.secure:
            if not srtp.protect(self.sendCtx, databuf, datalen, &datalen):
                clog("zstream", 7, "protect failed")
                return
            self.nrprotectedout += 1
        else:
            self.nrunprotectedout += 1
        self.sendData(databuf, datalen)
    
    #
    # RTCP
    #
    
    cdef void extCtrlDataReceived(self, const pj_sockaddr_t* addr, int addrlen, pj_uint8_t* databuf, pj_size_t datalen) nogil:
        if self.ice_state == ICE_STATE_CONNECTED:
            self.locSendCtrlData(databuf, datalen)
        else:
            self.cryptCtrlDataReceived(databuf, datalen)
        
    cdef void locCtrlDataReceived(self, const pj_sockaddr_t* addr, int addrlen, pj_uint8_t* databuf, pj_size_t datalen) nogil:
        if self.ice_state == ICE_STATE_CONNECTED:
            self.extSendCtrlData(databuf, datalen)
        else:
            self.cryptCtrlDataSend(databuf, datalen)
        
    cdef void extSendCtrlData(self, pj_uint8_t* databuf, pj_size_t datalen) nogil:
        if not self.addrsready: return
        self.extsockctrl.sendData(<pj_sockaddr_t*>&self.extdstaddrctrl, self.extdstaddrctrl_len, databuf, datalen)
        
    cdef void locSendCtrlData(self, pj_uint8_t* databuf, pj_size_t datalen) nogil:
        if not self.addrsready: return
        self.locsockctrl.sendData(<pj_sockaddr_t*>&self.locdstaddrctrl, self.locdstaddrctrl_len, databuf, datalen)
        
    cdef void iceCtrlDataReceived(self, const pj_sockaddr_t* addr, int addrlen, pj_uint8_t* databuf, pj_size_t datalen) nogil:
        # do not process anything until connected
        if self.ice_state != ICE_STATE_CONNECTED:
            return
        self.cryptCtrlDataReceived(databuf, datalen)

    cdef void iceSendCtrlData(self, pj_uint8_t* databuf, pj_size_t datalen) nogil:
        self.icestream.sendData(COMPID_RTCP, databuf, datalen)

    cdef void sendCtrlData(self, pj_uint8_t* databuf, pj_size_t datalen) nogil:        
        if self.ice_state == ICE_STATE_CONNECTED:
            self.iceSendCtrlData(databuf, datalen)
        else:
            self.extSendCtrlData(databuf, datalen)
            
    #
    # ZRTP / crypt handling (RTPCP)
    #
    
    cdef void cryptCtrlDataReceived(self, pj_uint8_t* databuf, pj_size_t datalen) nogil:
        if self.handshake:
            return
        cdef int res
        if self.recvCtxCtrl:
            res = srtp.unprotect(self.recvCtxCtrl, databuf, datalen, &datalen, NULL)
            if res != 1:
                clog("zstream", 1, "unprotect ctrl failed: %d", res)
                return
        self.locSendCtrlData(databuf, datalen)

    cdef void cryptCtrlDataSend(self, pj_uint8_t* databuf, pj_size_t datalen) nogil:
        if self.handshake:
            return
        if self.sendCtxCtrl:
            if not srtp.protect(self.sendCtxCtrl, databuf, datalen, &datalen):
                clog("zstream", 1, "protect ctrl failed")
                return
        self.sendCtrlData(databuf, datalen)
    
    #
    # ZRTP start / stop
    #
        
    cdef bool startZrtp(self) nogil:
        if self.zrtp_state >= ZRTP_STATE_STARTED:
            return True
        self.startHandshake()
        if not self.zcontext:
            self.zcontext = zrtp.zrtp_CreateWrapper()
            if not self.zcontext:
                with gil: logz.error("can not allocate zrtp engine")
                return False
            self.zsession.configureZrtp(self)
        pj_event_reset(self.zrtp_start_event)
        self.callOnThread(ZRTP_THREAD, <mq_handler_t>self.startZrtpEngine, NULL) # ...
        pj_event_wait(self.zrtp_start_event)
        self.zrtp_state = ZRTP_STATE_STARTED
        return True
    # ... continues here, on zrtp thread    
    cdef void startZrtpEngine(self, MQCBDATA *cbdata) nogil:
        zrtp.zrtp_startZrtpEngine(self.zcontext)
        if self.ice_state == ICE_STATE_NONE:
            self.zsession.cryptoStateInfo(self, CRYPTO_STATEINFO_ZRTP1)
        else:
            self.zsession.cryptoStateInfo(self, CRYPTO_STATEINFO_ZRTP2)
        pj_event_set(self.zrtp_start_event)
    
    cdef bool stopZrtp(self) nogil:
        self.zrtp_state = ZRTP_STATE_NONE
        pj_event_reset(self.zrtp_stop_event)
        self.callOnThread(ZRTP_THREAD, <mq_handler_t>self.stopZrtpEngine, NULL) # ...
        return True        
    # ... continues here, on zrtp thread
    cdef void stopZrtpEngine(self, MQCBDATA *cbdata) nogil:
        zrtp.zrtp_stopZrtpEngine(self.zcontext)
        zrtp.zrtp_DestroyWrapper(self.zcontext)
        self.zcontext = NULL
        pj_event_set(self.zrtp_stop_event)
            
    cdef void startHandshake(self) nogil:
        if self.handshake:
            return
        with gil: log.debug("start crypto handshake")
        self.handshake = True
        self.callOnThread(ZRTP_THREAD, <mq_handler_t>self.notifyHandshakeStart, NULL) # ...
    # ... continues here, on zrtp thread
    cdef void notifyHandshakeStart(self, MQCBDATA *cbdata) nogil:
        self.zsession.startCryptoHandshake(self)
        
    cdef void stopHandshake(self) nogil:
        if not self.handshake:
            return
        with gil: log.debug("stop crypto handshake: zrtp=(%d) %s, ice=(%d) %s", 
                            self.zrtp_state, ZrtpState_names[self.zrtp_state],
                            self.ice_state, IceState_names[self.ice_state])
        self.stopDTMF()
        self.handshake = False
        self.needsflush = True
        self.callOnThread(ZRTP_THREAD, <mq_handler_t>self.notifyHandshakeStop, NULL) # ...
    # ... continues here, on zrtp thread
    cdef void notifyHandshakeStop(self, MQCBDATA *cbdata) nogil:
        self.zsession.stopCryptoHandshake(self)
            
    #
    # zrtp callbacks. all callbacks are triggered from the zrtp thread,
    # so they are slow runners and may consume cpu.
    #
    
    cdef void logcallback(self, const char *name) nogil:
        if not self.logcb:
            return
        with gil: logz.debug(str(name))
            
    cdef void zrtpTimedout(self) nogil:
        if not <void*>self.zcontext:
            with gil: logz.debug("ZRTP old timedout...")
            return
        zrtp.zrtp_processTimeout(self.zcontext)
    
    cdef int32_t zrtp_sendDataZRTP(self, const uint8_t* data, int32_t length) nogil:
        cdef uint32_t datalen = length + zrtp.RTP_HEADER_LENGTH
        if datalen > zrtp.MAX_ZRTP_SIZE:
            with gil: logz.error("packet too big")
            return 0
        cdef pj_uint8_t* databuf = <pj_uint8_t*>malloc(datalen)
        if not databuf:
            with gil: logz.error("out of memory")
            return 0
        databuf[0] = 0x10
        databuf[1] = 0x00;
        (<uint16_t*>&databuf[2])[0] = pj_htons(self.senderZrtpSeqNo)
        (<uint32_t*>&databuf[4])[0] = pj_htonl(zrtp.ZRTP_MAGIC)
        (<uint32_t*>&databuf[8])[0] = 0 # SSRC
        self.senderZrtpSeqNo += 1
        memcpy(&databuf[zrtp.RTP_HEADER_LENGTH], data, length)
        cdef uint32_t crc = zrtp.zrtp_GenerateCksum(databuf, datalen-4)
        crc = zrtp.zrtp_EndCksum(crc)
        (<uint32_t*>&databuf[datalen-4])[0] = pj_htonl(crc)
        cdef MQCBDATA cbdata
        pj_memset(&cbdata, 0, sizeof(cbdata))
        cbdata.databuf = databuf
        cbdata.datalen = datalen
        self.callOnThread(RTP_THREAD, <mq_handler_t>self.zrtpOutput, &cbdata) # ...
        return 1
    # ... continue here, on rtp thread
    cdef void zrtpOutput(self, MQCBDATA *cbdata) nogil:
        if not <void*>self.zcontext:
            with gil: logz.debug("ZRTP old output packet...")
            return
        self.sendData(cbdata.databuf, cbdata.datalen)
    
    cdef int32_t zrtp_activateTimer(self, int32_t time) nogil:
        global g
        cdef pj_time_val time_val
        time_val.sec = time // 1000
        time_val.msec = time % 1000
        return pj_timer_heap_schedule(g.zrtp_timer_heap, &self.zrtp_timer, &time_val) == PJ_SUCCESS
    
    cdef int32_t zrtp_cancelTimer(self) nogil:
        global g
        pj_timer_heap_cancel(g.zrtp_timer_heap, &self.zrtp_timer)
        return 1
    
    cdef void zrtp_sendInfo(self, int32_t severity, int32_t subCode) nogil:
        self.logcallback("zrtp_sendInfo")
        self.zsession.showMessage(self, severity, subCode)
        
    cdef int32_t zrtp_srtpSecretsReady(self, zrtp.C_SrtpSecret_t* secrets, int32_t part) nogil:
        cdef int cipher
        cdef int authn
        cdef int authKeyLen
        cdef srtp.CryptoContext *send
        cdef srtp.CryptoContext *sendctrl
        cdef srtp.CryptoContext *recv
        cdef srtp.CryptoContext *recvctrl
        
        self.logcallback("zrtp_srtpSecretsReady")
        
        if self.logsecrets:
            #
            # WARNING: debug only! crypto keys on python heap!
            #
            with gil:
                logz.debug("who=%d,role=%d,auth=%d,enc=%d,atl=%d:", part, secrets.role, secrets.authAlgorithm, secrets.symEncAlgorithm, secrets.srtpAuthTagLen)
                if part == zrtp.ForSender:
                    if secrets.role == zrtp.Initiator:
                        key =  self.hexstr(secrets.keyInitiator,secrets.initKeyLen//8)
                        salt = self.hexstr(secrets.saltInitiator,secrets.initSaltLen//8)
                    else:
                        key =  self.hexstr(secrets.keyResponder,secrets.respKeyLen//8)
                        salt = self.hexstr(secrets.saltResponder,secrets.respSaltLen//8)
                else:
                    if secrets.role == zrtp.Initiator:
                        key =  self.hexstr(secrets.keyResponder,secrets.respKeyLen//8)
                        salt = self.hexstr(secrets.saltResponder,secrets.respSaltLen//8)
                    else:
                        key =  self.hexstr(secrets.keyInitiator,secrets.initKeyLen//8)
                        salt = self.hexstr(secrets.saltInitiator,secrets.initSaltLen//8)
                logz.debug("key=%s", key)
                logz.debug("sal=%s", salt)

        if secrets.authAlgorithm == zrtp.zrtp_Sha1:
            authn = srtp.SrtpAuthenticationSha1Hmac
            authKeyLen = 20
        elif secrets.authAlgorithm == zrtp.zrtp_Skein:
            authn = srtp.SrtpAuthenticationSkeinHmac;
            authKeyLen = 32;

        if secrets.symEncAlgorithm == zrtp.zrtp_Aes:
            cipher = srtp.SrtpEncryptionAESCM
        elif secrets.symEncAlgorithm == zrtp.zrtp_TwoFish:
            cipher = srtp.SrtpEncryptionTWOCM

        if part == zrtp.ForSender:
            # To encrypt packets: intiator uses initiator keys,
            # responder uses responder keys
            # This is the main crypto context for the sending part of the connection.
            if self.sendCtx:
                with gil: logz.warning("duplicate key ignored")
                return True
            if secrets.role == zrtp.Initiator:
                send = new srtp.CryptoContext(0,
                                              0,
                                              0,                                 #keyderivation << 48,
                                              cipher,                            #encryption algo
                                              authn,                             #authtentication algo
                                              <uint8_t*>secrets.keyInitiator,    #Master Key
                                              secrets.initKeyLen // 8,           #Master Key length
                                              <uint8_t*>secrets.saltInitiator,   #Master Salt
                                              secrets.initSaltLen // 8,          #Master Salt length
                                              secrets.initKeyLen // 8,           #encryption keyl
                                              authKeyLen,                        #authentication key len
                                              secrets.initSaltLen // 8,          #session salt len
                                              secrets.srtpAuthTagLen // 8)       #authentication tag lenA
                sendctrl = new srtp.CryptoContext(0,
                                                  0,
                                                  0,                                 #keyderivation << 48,
                                                  cipher,                            #encryption algo
                                                  authn,                             #authtentication algo
                                                  <uint8_t*>secrets.keyInitiator,    #Master Key
                                                  secrets.initKeyLen // 8,           #Master Key length
                                                  <uint8_t*>secrets.saltInitiator,   #Master Salt
                                                  secrets.initSaltLen // 8,          #Master Salt length
                                                  secrets.initKeyLen // 8,           #encryption keyl
                                                  authKeyLen,                        #authentication key len
                                                  secrets.initSaltLen // 8,          #session salt len
                                                  secrets.srtpAuthTagLen // 8)       #authentication tag lenA
            else:
                send = new srtp.CryptoContext(0,
                                              0,
                                              0,                                 #keyderivation << 48,
                                              cipher,                            #encryption algo
                                              authn,                             #authtentication algo
                                              <uint8_t*>secrets.keyResponder,    #Master Key
                                              secrets.respKeyLen // 8,           #Master Key length
                                              <uint8_t*>secrets.saltResponder,   #Master Salt
                                              secrets.respSaltLen // 8,          #Master Salt length
                                              secrets.respKeyLen // 8,           #encryption keyl
                                              authKeyLen,                        #authentication key len
                                              secrets.respSaltLen // 8,          #session salt len
                                              secrets.srtpAuthTagLen // 8)       #authentication tag len
                sendctrl = new srtp.CryptoContext(0,
                                                  0,
                                                  0,                                 #keyderivation << 48,
                                                  cipher,                            #encryption algo
                                                  authn,                             #authtentication algo
                                                  <uint8_t*>secrets.keyResponder,    #Master Key
                                                  secrets.respKeyLen // 8,           #Master Key length
                                                  <uint8_t*>secrets.saltResponder,   #Master Salt
                                                  secrets.respSaltLen // 8,          #Master Salt length
                                                  secrets.respKeyLen // 8,           #encryption keyl
                                                  authKeyLen,                        #authentication key len
                                                  secrets.respSaltLen // 8,          #session salt len
                                                  secrets.srtpAuthTagLen // 8)       #authentication tag len
            if not send or not sendctrl:
                del send
                del sendctrl
                return False
            send.deriveSrtpKeys(0);
            sendctrl.deriveSrtpKeys(0);
            self.sendCtx = send
            self.sendCtxCtrl = sendctrl
        elif part == zrtp.ForReceiver:
            if self.recvCtx:
                with gil: logz.warning("duplicate key ignored")
                return True
            # To decrypt packets: intiator uses responder keys,
            # responder initiator keys
            # See comment above.
            if secrets.role == zrtp.Initiator:
                recv = new srtp.CryptoContext(0,
                                              0,
                                              0,                                 #keyderivation << 48,
                                              cipher,                            #encryption algo
                                              authn,                             #authtentication algo
                                              <uint8_t*>secrets.keyResponder,    #Master Key
                                              secrets.respKeyLen // 8,           #Master Key length
                                              <uint8_t*>secrets.saltResponder,   #Master Salt
                                              secrets.respSaltLen // 8,          #Master Salt length
                                              secrets.respKeyLen // 8,           #encryption keyl
                                              authKeyLen,                        #authentication key len
                                              secrets.respSaltLen // 8,          #session salt len
                                              secrets.srtpAuthTagLen // 8)       #authentication tag len
                recvctrl = new srtp.CryptoContext(0,
                                                  0,
                                                  0,                                 #keyderivation << 48,
                                                  cipher,                            #encryption algo
                                                  authn,                             #authtentication algo
                                                  <uint8_t*>secrets.keyResponder,    #Master Key
                                                  secrets.respKeyLen // 8,           #Master Key length
                                                  <uint8_t*>secrets.saltResponder,   #Master Salt
                                                  secrets.respSaltLen // 8,          #Master Salt length
                                                  secrets.respKeyLen // 8,           #encryption keyl
                                                  authKeyLen,                        #authentication key len
                                                  secrets.respSaltLen // 8,          #session salt len
                                                  secrets.srtpAuthTagLen // 8)       #authentication tag len
            else:
                recv = new srtp.CryptoContext(0,
                                              0,
                                              0,                                 #keyderivation << 48,
                                              cipher,                            #encryption algo
                                              authn,                             #authtentication algo
                                              <uint8_t*>secrets.keyInitiator,    #Master Key
                                              secrets.initKeyLen // 8,           #Master Key length
                                              <uint8_t*>secrets.saltInitiator,   #Master Salt
                                              secrets.initSaltLen // 8,          #Master Salt length
                                              secrets.initKeyLen // 8,           #encryption keyl
                                              authKeyLen,                        #authentication key len
                                              secrets.initSaltLen // 8,          #session salt len
                                              secrets.srtpAuthTagLen // 8)       #authentication tag len
                recvctrl = new srtp.CryptoContext(0,
                                                  0,
                                                  0,                                 #keyderivation << 48,
                                                  cipher,                            #encryption algo
                                                  authn,                             #authtentication algo
                                                  <uint8_t*>secrets.keyInitiator,    #Master Key
                                                  secrets.initKeyLen // 8,           #Master Key length
                                                  <uint8_t*>secrets.saltInitiator,   #Master Salt
                                                  secrets.initSaltLen // 8,          #Master Salt length
                                                  secrets.initKeyLen // 8,           #encryption keyl
                                                  authKeyLen,                        #authentication key len
                                                  secrets.initSaltLen // 8,          #session salt len
                                                  secrets.srtpAuthTagLen // 8)       #authentication tag len
            if not recv or not recvctrl:
                del recv
                del recvctrl
                return False
            recv.deriveSrtpKeys(0);
            recvctrl.deriveSrtpKeys(0);
            self.recvCtx = recv
            self.recvCtxCtrl = recvctrl
        return True
    
    cdef void zrtp_srtpSecretsOff(self, int32_t part) nogil:
        self.logcallback("zrtp_srtpSecretsOff")
        if part == zrtp.ForSender:
            del self.sendCtx
            self.sendCtx = NULL
        elif part == zrtp.ForReceiver:
            del self.recvCtx
            self.recvCtx = NULL
        if self.secure:
            self.secure = False
            self.zsession.secureOff(self)
        
    cdef void zrtp_rtpSecretsOn(self, char* c, char* s, int32_t verified) nogil:
        self.logcallback("zrtp_srtpSecretsOn")
        if self.secure:
            return
        self.secure = True
        with gil:
            self.received_cipher = c
            self.received_sas = s
        self.verified = verified
        self.zrtp_state = ZRTP_STATE_CONNECTED
        if s and s[0]:
            self.zsession.secureOn(self, self.received_cipher, self.received_sas, self.verified)
        self.zsession.cryptoStateInfo(self, CRYPTO_STATEINFO_CONNECTED)
        self.zrtp_stopHandshake()
    
    cdef void zrtp_handleGoClear(self) nogil:
        self.logcallback("zrtp_handleGoClear")
        self.zsession.handleGoClear(self)
        
    cdef void zrtp_zrtpNegotiationFailed(self, int32_t severity, int32_t subCode) nogil:
        self.logcallback("zrtp_zrtpNegotiationFailed")
        self.zrtp_state = ZRTP_STATE_FAILED
        self.failed_severity = severity
        self.failed_subcode = subCode
        if self.ice_state == ICE_STATE_NONE:
            # 1. try failed, start ice
            self.startICE()
        else:
            self.zsession.zrtpNegotiationFailed(self, severity, subCode)
            self.zsession.cryptoStateInfo(self, CRYPTO_STATEINFO_FAILED)
            self.zrtp_stopHandshake()
    
    cdef void zrtp_zrtpNotSuppOther(self) nogil:
        self.logcallback("zrtp_zrtpNotSuppOther")
        self.zrtp_state = ZRTP_STATE_FAILED
        self.failed_severity = zrtp.zrtp_ZrtpError
        self.failed_subcode = _zrtp_NotSupported
        if self.ice_state == ICE_STATE_NONE:
            # 1. try failed, start ice
            self.startICE()
        else:
            self.zsession.zrtpNotSuppOther(self)
            self.zsession.cryptoStateInfo(self, CRYPTO_STATEINFO_FAILED)
            self.zrtp_stopHandshake()
            
    cdef void zrtp_synchEnter(self) nogil:
        pj_lock_acquire(self.zrtp_lock)
    
    cdef void zrtp_synchLeave(self) nogil:
        pj_lock_release(self.zrtp_lock)
    
    cdef void zrtp_zrtpAskEnrollment(self, int32_t info) nogil:
        self.logcallback("zrtp_zrtpAskEnrollment")
        self.zsession.zrtpAskEnrollment(self, info)
    
    cdef void zrtp_zrtpInformEnrollment(self, int32_t info) nogil:
        self.logcallback("zrtp_zrtpInfoEnrollment")
        self.zsession.zrtpInformEnrollment(self, info)
    
    cdef void zrtp_signSAS(self, uint8_t* sas) nogil:
        self.logcallback("zrtp_signSAS")
        self.zsession.signSAS(self, sas)
    
    cdef int32_t zrtp_checkSASSignature(self, uint8_t* sas) nogil:
        self.logcallback("zrtp_checkSASSignature")
        return self.zsession.checkSASSignature(self, sas)
    
    cdef void zrtp_stopHandshake(self) nogil:
        self.callOnThread(RTP_THREAD, <mq_handler_t>self.stopHandshake, NULL)
        
    #
    # ICE
    #
    cdef bool handleDTMF(self, pj_uint8_t* databuf) with gil:
        if databuf[12] == DTMF_START: 
            self.remote_started_ice = True
            self.startICE()
        if not self.handshake:
            return False
        if self.dtmfex:
            self.dtmfex.inputData(databuf)
        return True
    
    cdef bool startICE(self) nogil:
        self.callOnThread(RTP_THREAD, <mq_handler_t>self.do_start_ice, NULL)
        return True
    
    cdef void do_start_ice(self) nogil:
        if self.ice_state != ICE_STATE_NONE:
            return
        if self.zrtp_state != ZRTP_STATE_NONE:
            self.stopZrtp()
        self.startKeepAlive()
        self.startHandshake()
        with gil:
            try:
                if not config.has_option(consts.SECTION, consts.ICESTORAGEURL):
                    logi.error("no icestorage server defined")
                    self.onICEFailed()
                    return
                if self.logice: logi.debug("starting ice handshake.")
                self.dtmfex = MyDTMFExchange(self, self.remote_started_ice, self.audioinfo)
                self.ice_state = ICE_STATE_STARTED
                self.zsession.cryptoStateInfo(self, CRYPTO_STATEINFO_LOCAL_OFFER)
                self.icestream = MyICEStream(self,
                                             config.safe_get(consts.SECTION, consts.ICESTORAGEURL),
                                             config.safe_get(consts.SECTION, consts.DNSSERVER), 
                                             config.safe_get(consts.SECTION, consts.STUNSERVER),
                                             config.safe_get(consts.SECTION, consts.TURNSERVER),
                                             config.safe_get(consts.SECTION, consts.TURNUSER),
                                             config.safe_get(consts.SECTION, consts.TURNPASSWORD))
            except Exception as e:
                logi.error("%s", e, exc_info = exc_info())
                self.onICEFailed()
                
    cdef void localIdReceived(self, localid) with gil:
        if self.logice:
            logi.debug("local offer: %s", self.icestream.conf2dict()) 
            logi.debug("localid received: %s", localid)
        self.dtmfex.localIdReceived(localid)
        self.zsession.cryptoStateInfo(self, CRYPTO_STATEINFO_DTMF_EXCHANGE)
        
    def onDTMFDone(self, remoteid):
        # remoteid received. 
        # setRemoteId() also starts the ice handshake!
        self.icestream.setRemoteId(remoteid)
        self.zsession.cryptoStateInfo(self, CRYPTO_STATEINFO_ICE)
        
    def onDTMFFailed(self):
        logi.error("dtmf exchange failed")
        self.onICEFailed()
        
    cdef void stopDTMF(self) with gil:
        if self.dtmfex:
            self.dtmfex.close()
            
    def onICEConnected(self):
        global g
        if self.logice: logi.debug("ice connection succeeded")
        self.ice_state = ICE_STATE_CONNECTED
        with nogil: self.startZrtp()
        self.zsession.cryptoStateInfo(self, CRYPTO_STATEINFO_ZRTP2)
            
    def onICEFailed(self):
        logi.error("ice connection failed")
        self.ice_state = ICE_STATE_FAILED
        self.zsession.cryptoStateInfo(self, CRYPTO_STATEINFO_FAILED)
        self.stopHandshake()
        
    cdef void startKeepAlive(self) nogil:
        global g
        cdef pj_time_val tv
        tv.sec  = KEEPALIVESECS
        tv.msec = 0
        pj_timer_heap_schedule(g.rtp_timer_heap, &self.keepalive_timer, &tv)
        
    cdef void sendKeepAlivePacket(self) nogil:
        cdef pj_time_val now
        cdef uint64_t    nowms
        cdef uint64_t    intimems
        cdef uint32_t    timestamp
        cdef uint16_t    ptime
        ptime = self.audioinfo.ptime
        pj_gettimeofday(&now)
        nowms    = pjtime2ms(&now)
        intimems = pjtime2ms(&self.loctime)
        nowms    = nowms // ptime * ptime
        intimems = intimems // ptime * ptime 
        timestamp = self.loctimestamp + (nowms-intimems) * self.audioinfo.ticks1ms
        (<uint16_t*>&self.keepalive_packet[2])[0] = pj_htons(self.locseq+self.locoffset)
        self.locoffset += 1
        (<uint32_t*>&self.keepalive_packet[4])[0] = pj_htonl(timestamp)
        (<uint32_t*>&self.keepalive_packet[8])[0] = pj_htonl(self.locSSRC)
        self.extSendData(self.keepalive_packet, self.keepalive_packet_len)

    cdef void keepaliveTimedout(self) nogil:
        self.sendKeepAlivePacket()
        self.startKeepAlive()
        
#
# glue classes
#

cdef class MyDTMFExchange(DTMFExchange):
    
    cdef CyRTPStream stream
    
    def __init__(self, CyRTPStream stream, bool insync, AUDIOINFO audioinfo):
        self.stream = stream
        super(MyDTMFExchange, self).__init__(stream.isIncoming, insync, audioinfo)
        
    def onDone(self, remoteid):
        self.stream.onDTMFDone(remoteid)
    
    def onFailed(self):
        self.stream.onDTMFFailed()
    
    cdef uint64_t getTimeMS(self) nogil:
        return pjtime2ms(&self.stream.loctime)
    
    cdef uint32_t getTimestamp(self) nogil:
        return self.stream.loctimestamp
    
    cdef uint16_t getSeq(self) nogil:
        return self.stream.locseq + self.stream.locoffset
    
    cdef uint32_t getSSRC(self) nogil:
        return self.stream.locSSRC
    
    cdef void incOffset(self) nogil:
        self.stream.locoffset = self.stream.locoffset + 1
        
    cdef void outputData(self, pj_uint8_t* databuf, pj_size_t datalen) nogil:
        self.stream.extSendData(databuf, datalen)
    
            
cdef class MyICEStream(PJICEStream):
        
    cdef CyRTPStream stream

    def __init__(self, CyRTPStream stream, storageurl, dns_server, stun_server, turn_server, turn_user, turn_pwd):
        self.stream = stream
        host = stream.zsession.getExtHost()
        super(MyICEStream, self).__init__(stream.isIncoming, 
                                          host, 
                                          storageurl, 
                                          dns_server, 
                                          stun_server, 
                                          turn_server, 
                                          turn_user, 
                                          turn_pwd) 
        
    def onLocalId(self, id):
        self.stream.localIdReceived(id)
    
    def onConnected(self):
        self.stream.onICEConnected()
    
    def onFailed(self):
        self.stream.onICEFailed()

    cdef void on_rx_data(self, unsigned comp_id, void* pkt, pj_size_t size, const pj_sockaddr_t* src_addr, unsigned src_addr_len) nogil:
        if comp_id == COMPID_RTP:
            self.stream.iceDataReceived(src_addr, src_addr_len, <pj_uint8_t*>pkt, size)
        else:
            self.stream.iceCtrlDataReceived(src_addr, src_addr_len, <pj_uint8_t*>pkt, size)
            
#
# callback glue
#

cdef void CyRTPStream_zrtp_timedout(pj_timer_heap_t* ht, pj_timer_entry* entry) nogil:
    (<CyRTPStream>entry.user_data).zrtpTimedout()
    
cdef void CyRTPStream_keepalive_timedout(pj_timer_heap_t* ht, pj_timer_entry* entry) nogil:
    (<CyRTPStream>entry.user_data).keepaliveTimedout()

#
# zrtp callback glue
#

cdef int32_t zrtp_sendDataZRTP(zrtp.ZrtpContext *context, const uint8_t* data, int32_t length) nogil:
    return (<CyRTPStream>context.userData).zrtp_sendDataZRTP(data, length)

callbacks.zrtp_sendDataZRTP = zrtp_sendDataZRTP

cdef int32_t zrtp_activateTimer(zrtp.ZrtpContext *context, int32_t time) nogil:
    return (<CyRTPStream>context.userData).zrtp_activateTimer(time)

callbacks.zrtp_activateTimer = zrtp_activateTimer

cdef int32_t zrtp_cancelTimer(zrtp.ZrtpContext *context) nogil:
    return (<CyRTPStream>context.userData).zrtp_cancelTimer()

callbacks.zrtp_cancelTimer = zrtp_cancelTimer

cdef void zrtp_sendInfo(zrtp.ZrtpContext *context, int32_t severity, int32_t subCode) nogil:
    (<CyRTPStream>context.userData).zrtp_sendInfo(severity, subCode)

callbacks.zrtp_sendInfo = zrtp_sendInfo

cdef int32_t zrtp_srtpSecretsReady(zrtp.ZrtpContext *context, zrtp.C_SrtpSecret_t* secrets, int32_t part) nogil:
    return (<CyRTPStream>context.userData).zrtp_srtpSecretsReady(secrets, part)

callbacks.zrtp_srtpSecretsReady = zrtp_srtpSecretsReady

cdef void zrtp_srtpSecretsOff(zrtp.ZrtpContext *context, int32_t part) nogil:
    (<CyRTPStream>context.userData).zrtp_srtpSecretsOff(part)

callbacks.zrtp_srtpSecretsOff = zrtp_srtpSecretsOff

cdef void zrtp_rtpSecretsOn(zrtp.ZrtpContext *context, char* c, char* s, int32_t verified) nogil:
    (<CyRTPStream>context.userData).zrtp_rtpSecretsOn(c, s, verified)

callbacks.zrtp_rtpSecretsOn = zrtp_rtpSecretsOn

cdef void zrtp_handleGoClear(zrtp.ZrtpContext *context) nogil:
    (<CyRTPStream>context.userData).zrtp_handleGoClear()

callbacks.zrtp_handleGoClear = zrtp_handleGoClear

cdef void zrtp_zrtpNegotiationFailed(zrtp.ZrtpContext *context, int32_t severity, int32_t subCode) nogil:
    (<CyRTPStream>context.userData).zrtp_zrtpNegotiationFailed(severity, subCode)

callbacks.zrtp_zrtpNegotiationFailed = zrtp_zrtpNegotiationFailed

cdef void zrtp_zrtpNotSuppOther(zrtp.ZrtpContext *context) nogil:
    (<CyRTPStream>context.userData).zrtp_zrtpNotSuppOther()

callbacks.zrtp_zrtpNotSuppOther = zrtp_zrtpNotSuppOther

cdef void zrtp_synchEnter(zrtp.ZrtpContext *context) nogil:
    (<CyRTPStream>context.userData).zrtp_synchEnter()

callbacks.zrtp_synchEnter = zrtp_synchEnter

cdef void zrtp_synchLeave(zrtp.ZrtpContext *context) nogil:
    (<CyRTPStream>context.userData).zrtp_synchLeave()

callbacks.zrtp_synchLeave = zrtp_synchLeave

cdef void zrtp_zrtpAskEnrollment(zrtp.ZrtpContext *context, int32_t info) nogil:
    (<CyRTPStream>context.userData).zrtp_zrtpAskEnrollment(info)

callbacks.zrtp_zrtpAskEnrollment = zrtp_zrtpAskEnrollment

cdef void zrtp_zrtpInformEnrollment(zrtp.ZrtpContext *context, int32_t info) nogil:
    (<CyRTPStream>context.userData).zrtp_zrtpInformEnrollment(info)

callbacks.zrtp_zrtpInformEnrollment = zrtp_zrtpInformEnrollment

cdef void zrtp_signSAS(zrtp.ZrtpContext *context, uint8_t* sas) nogil:
    (<CyRTPStream>context.userData).zrtp_signSAS(sas)

callbacks.zrtp_signSAS = zrtp_signSAS

cdef int32_t zrtp_checkSASSignature(zrtp.ZrtpContext *context, uint8_t* sas) nogil:
    (<CyRTPStream>context.userData).zrtp_checkSASSignature(sas)

callbacks.zrtp_checkSASSignature = zrtp_checkSASSignature
