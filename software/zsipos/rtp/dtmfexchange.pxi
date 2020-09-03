# SPDX-FileCopyrightText: 2019 Stefan Adams <stefan.adams@vipcomag.de>
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

#dtmf
DEF DTMFIDLEN = 10

DEF DTMFOUTBUFLEN = 16

DEF DTMF_START        = 10
DEF DTMF_START_CHAR   = '*' 
DEF DTMF_CONFIRM      = 11
DEF DTMF_CONFIRM_CHAR = '#'

cdef class DTMFExchange:

    cdef bool           incoming
    cdef bool           insync
    cdef int            tms
    cdef bool           closed
    
    cdef pj_timer_entry localidout_timer
    cdef object         localid
    cdef object         remoteid
    cdef bool           remote_has_my_id
    cdef bool           done
    cdef uint8_t        lastDigit
    cdef object         receivedDigits

    cdef bool           logdtmf
    cdef AUDIOINFO      audioinfo
    cdef uint8_t        dtmfOutPT
    cdef uint16_t       dtmfOutDuration
    cdef uint16_t       dtmfOutPause
    cdef object         dtmfOutChars
    cdef int            dtmfOutPos
    cdef int            dtmfOutLen
    cdef uint32_t       dtmfTimestamp
    cdef pj_timer_entry charout_timer
    cdef pj_uint8_t     dtmfCurrChar
    cdef int            dtmfOutPacket
    cdef pj_uint8_t     dtmfOutBuf[8][DTMFOUTBUFLEN]
    cdef pj_timer_entry packetout_timer
    cdef int            nrdtmfin
    cdef int            nrdtmfout          
    
    def __init__(self, bool incoming, bool insync, AUDIOINFO audioinfo):
        self.incoming = incoming
        self.insync = insync
        self.audioinfo = audioinfo
        self.logdtmf = config.getboolean(consts.SECTION, consts.LOGDTMF)
        self.dtmfOutPT = audioinfo.pt
        self.dtmfOutDuration = self.normalize_ptime(80)
        self.dtmfOutPause = self.normalize_ptime(60)
        self.tms = (self.dtmfOutDuration+self.dtmfOutPause)*(DTMFIDLEN+3) # 1 char start, 2 char crc
        self.remote_has_my_id = False
        pj_timer_entry_init(&self.charout_timer, 1, <void*>self, DTMFExchange_charout_timedout)
        pj_timer_entry_init(&self.packetout_timer, 2, <void*>self, DTMFExchange_packetout_timedout)
        self.lastDigit = ord('X')
        self.receivedDigits = {}
        pj_timer_entry_init(&self.localidout_timer, 3, <void*>self, DTMFExchange_localidout_timedout)
        
    cdef uint64_t normalize_ptime(self, uint64_t val) nogil:
        if val % self.audioinfo.ptime:
            val = ((val + self.audioinfo.ptime) // self.audioinfo.ptime) * self.audioinfo.ptime
        else:
            return val
        
    def dealloc(self):
        self.close_timers()
        
    def close(self):
        self.closed = True
        logd.debug("nr dtmf packets in : %d", self.nrdtmfin)
        logd.debug("nr dtmf packets out: %d", self.nrdtmfout)
        self.close_timers()
        
    def close_timers(self):
        global g
        pj_timer_heap_cancel(g.rtp_timer_heap, &self.packetout_timer)
        pj_timer_heap_cancel(g.rtp_timer_heap, &self.charout_timer)
        pj_timer_heap_cancel(g.rtp_timer_heap, &self.localidout_timer)
        #self.debug_timers()
        
    def debug_timers(self):
        logd.debug("localidout: %d", pj_timer_entry_running(&self.localidout_timer))
        logd.debug("charout   : %d", pj_timer_entry_running(&self.charout_timer))
        logd.debug("packetout : %d", pj_timer_entry_running(&self.packetout_timer))
        
    cdef void error_timer(self) nogil:
        with gil:
            logd.error("canceled timer fired!")
        
    #
    # interface glue
    #
    
    def onDone(self, remoteid):
        pass
    
    def onFailed(self):
        pass
    
    cdef uint64_t getTimeMS(self) nogil:
        return 0
    
    cdef uint32_t getTimestamp(self) nogil:
        return 0
    
    cdef uint16_t getSeq(self) nogil:
        return 0
    
    cdef uint32_t getSSRC(self) nogil:
        return 0
    
    cdef void incOffset(self) nogil:
        pass
    
    cdef void outputData(self, pj_uint8_t* databuf, pj_size_t datalen) nogil:
        pass
    
    #
    # input
    #
    
    cdef void inputData(self, pj_uint8_t* databuf) with gil:
        cdef uint8_t c = databuf[12]
        self.checkDone()
        self.insync = True
        self.nrdtmfin += 1
        if self.closed:
            self.error_timer()
            return
        if self.dtmfOutChars: # simulate half duplex
            return
        self.close_timers()
        self.dispatchIdTransmission(self.tms//3)
        if self.done: # no more interpretation needed
            return
        timestamp = pj_ntohl((<uint32_t*>&databuf[4])[0])
        if timestamp in self.receivedDigits:
            return
        if c == DTMF_START or c == DTMF_CONFIRM: 
            self.receivedDigits = {}
            self.lastDigit = c
            if c == DTMF_CONFIRM:
                self.remote_has_my_id = True
            return
        if c >= 0 and c <= 9:
            if c == self.lastDigit:
                return
            self.lastDigit = c
            self.receivedDigits[timestamp] = c
            if len(self.receivedDigits) == DTMFIDLEN + 2: # 2 char crc
                remoteid = "".join([chr(self.receivedDigits[i]+ord('0')) for i in sorted(self.receivedDigits)])
                if self.logdtmf: 
                    if self.remote_has_my_id:
                        s = DTMF_CONFIRM_CHAR + remoteid
                    else:
                        s = DTMF_START_CHAR + remoteid
                    logd.debug("dtmfin : %s", s)
                if self.crc(remoteid[:-2]) == remoteid[-2:]:
                    self.remoteIdReceived(remoteid[:-2])
                else:
                    logd.warning("crc mismatch")
        
    def localIdReceived(self, localid):
        if self.closed:
            return
        self.localid = localid
        if not self.insync: # we started the handshake
            self.close_timers()
            self.dispatchIdTransmission(0)
        
    def remoteIdReceived(self, remoteid):
        if self.remoteid:
            if self.remoteid != remoteid:
                logd.warning("remoteid mismatch: already have %s", self.remoteid)
            return
        if not self.remoteid:
            if self.logdtmf: logd.debug("remoteid received: %s", remoteid)
            self.remoteid = remoteid
        
    #
    # check for done
    #
    
    cdef void checkDone(self) with gil:
        if not self.done and self.remote_has_my_id and self.remoteid:
            self.done = True
            self.onDone(self.remoteid)
           
    #
    # output
    #
    
    def crc(self, s):
        l = long(s)
        return "%02d" % (98 - l % 97)
    
    def dtmfLocalidOut(self, id):
        if self.remoteid:
            id = DTMF_CONFIRM_CHAR + id + self.crc(id)
        else:
            id = DTMF_START_CHAR + id + self.crc(id)
        self.dtmfStringOut(id)
        
    def dtmfStringOut(self, chars):
        global g
        cdef uint16_t ptime
        cdef pj_time_val now
        cdef uint64_t nowms
        cdef uint64_t intimems
        cdef uint64_t futuretimems # normalized to ptime
        cdef uint64_t diffms # now to futuretime
        if self.logdtmf: 
            logd.debug("dtmfout: %s", chars)
        #check if theres already something to output
        if self.dtmfOutChars:
            logd.debug("oops")
            return
        self.dtmfOutChars = chars
        self.dtmfOutLen = len(chars)
        self.dtmfOutPos = 0
        ptime = self.audioinfo.ptime
        pj_gettimeofday(&now)
        nowms = pjtime2ms(&now)
        intimems = (self.getTimeMS() // ptime) * ptime
        futuretimems = ((nowms + ptime) // ptime) * ptime
        self.dtmfTimestamp = self.getTimestamp() + (futuretimems - intimems) * self.audioinfo.ticks1ms
        diffms = futuretimems - nowms
        cdef pj_time_val time_val
        time_val.sec  = diffms // 1000
        time_val.msec = diffms % 1000
        pj_timer_heap_schedule(g.rtp_timer_heap, &self.charout_timer, &time_val)
        
    def dtmfCharOut(self, c):
        if c >= '0' and c <= '9':
            c = ord(c) - ord('0')
        elif c == '*':
            c = 10
        elif c == '#':
            c = 11
        elif c >= 'A' and c <= 'D':
            c = ord(c) - ord('A') + 12
        else:
            raise Exception("invalid dtmf char: " + c)
        self.dtmfCurrChar  = c
        self.dtmfOutPacket = 0
        self.dtmfSendPacket()
        
    cdef void dtmfSendPacket(self) nogil:
        cdef pj_uint8_t* databuf
        cdef pj_time_val time_val
        databuf = self.dtmfOutBuf[self.dtmfOutPacket]
        databuf[0] = 0x80
        databuf[1] = self.dtmfOutPT
        if self.dtmfOutPacket == 0:
            databuf[1] |= 0x80
        self.incOffset()
        (<uint16_t*>&databuf[2])[0] = self.getSeq()
        (<uint32_t*>&databuf[4])[0] = pj_htonl(self.dtmfTimestamp)
        (<uint32_t*>&databuf[8])[0] = pj_htonl(self.getSSRC())
        databuf[12] = self.dtmfCurrChar
        if self.dtmfOutPacket > 3:
            databuf[13] = 0x80
            (<uint16_t*>&databuf[14])[0] = pj_htons(4*self.audioinfo.ptime*self.audioinfo.ticks1ms)
        else:             
            databuf[13] = 0
            (<uint16_t*>&databuf[14])[0] = pj_htons(self.dtmfOutPacket*self.audioinfo.ptime*self.audioinfo.ticks1ms)
        self.nrdtmfout += 1
        self.outputData(databuf, DTMFOUTBUFLEN)
        self.dtmfOutPacket += 1
        if self.dtmfOutPacket < 8:
            time_val.sec  = 0
            time_val.msec = self.audioinfo.ptime
            pj_timer_heap_schedule(g.rtp_timer_heap, &self.packetout_timer, &time_val)
        else:
            self.dtmfOutPos += 1
            if self.dtmfOutPos < self.dtmfOutLen:
                self.dtmfTimestamp += (self.dtmfOutDuration + self.dtmfOutPause) * self.audioinfo.ticks1ms
                time_val.sec  = 0
                time_val.msec = self.audioinfo.ptime
                pj_timer_heap_schedule(g.rtp_timer_heap, &self.charout_timer, &time_val)
            else:
                self.checkDone()
                self.dispatchNextIdTransmission()

    cdef void packetOutTimedout(self) nogil:
        if self.closed: 
            self.error_timer()
            return
        self.dtmfSendPacket()
            
    cdef void charOutTimedout(self) with gil:
        if self.closed: 
            self.error_timer()
            return
        try:
            self.dtmfCharOut(self.dtmfOutChars[self.dtmfOutPos])
        except Exception as e:
            logd.error("%s", e, exc_info = exc_info())
            self.onFailed()
                                
    cdef void dispatchNextIdTransmission(self) nogil:
        if self.incoming:
            self.dispatchIdTransmission(self.tms * 2)
        else:
            self.dispatchIdTransmission(self.tms)
            
    cdef void dispatchIdTransmission(self, int d) with gil:
        cdef pj_time_val time_val
        if not self.localid:
            return
        self.dtmfOutChars = None
        time_val.sec  = (d // 1000)
        time_val.msec = (d % 1000)
        pj_timer_heap_schedule(g.rtp_timer_heap, &self.localidout_timer, &time_val)
            
    cdef void localidTimedout(self) with gil:
        if self.closed: 
            self.error_timer()
            return
        try:
            self.dtmfLocalidOut(self.localid)
        except Exception as e:
            logd.error("%s", e, exc_info = exc_info())
            self.onFailed()
            
    
#
# callback glue
#

cdef void DTMFExchange_localidout_timedout(pj_timer_heap_t* ht, pj_timer_entry* entry) with gil:
    (<DTMFExchange>entry.user_data).localidTimedout()

cdef void DTMFExchange_charout_timedout(pj_timer_heap_t* ht, pj_timer_entry* entry) with gil:
    (<DTMFExchange>entry.user_data).charOutTimedout()

cdef void DTMFExchange_packetout_timedout(pj_timer_heap_t* ht, pj_timer_entry* entry) with gil:
    (<DTMFExchange>entry.user_data).packetOutTimedout()

