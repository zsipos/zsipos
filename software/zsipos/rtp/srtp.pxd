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
from stdint cimport *
from libcpp cimport bool
from zrtp   cimport SrtpErrorData

cdef extern from "srtp/CryptoContext.h":

# All definitions.
# From top --> bottom.
    
    cdef int REPLAY_WINDOW_SIZE

    cdef int SrtpAuthenticationNull
    cdef int SrtpAuthenticationSha1Hmac
    cdef int SrtpAuthenticationSkeinHmac

    cdef int SrtpEncryptionNull
    cdef int SrtpEncryptionAESCM
    cdef int SrtpEncryptionAESF8
    cdef int SrtpEncryptionTWOCM
    cdef int SrtpEncryptionTWOF8

    cdef cppclass CryptoContext:
        CryptoContext(uint32_t ssrc, int32_t roc,
                      int64_t  keyDerivRate,
                      const  int32_t ealg,
                      const  int32_t aalg,
                      uint8_t* masterKey,
                      int32_t  masterKeyLength,
                      uint8_t* masterSalt,
                      int32_t  masterSaltLength,
                      int32_t  ekeyl,
                      int32_t  akeyl,
                      int32_t  skeyl,
                      int32_t  tagLength) nogil
        void     setRoc(uint32_t r) nogil
        uint32_t getRoc() nogil
        void     srtpEncrypt(uint8_t* pkt, uint8_t* payload, uint32_t paylen, uint64_t index, uint32_t ssrc) nogil
        void     srtpAuthenticate(uint8_t* pkt, uint32_t pktlen, uint32_t roc, uint8_t* tag) nogil
        void     deriveSrtpKeys(uint64_t index) nogil
        uint64_t guessIndex(uint16_t newSeqNumber) nogil
        bool     checkReplay(uint16_t newSeqNumber) nogil
        void     update(uint16_t newSeqNumber) nogil
        int32_t  getTagLength() nogil
        int32_t  getMkiLength() nogil
        uint32_t getSsrc() nogil
        void     setLabelbase(uint8_t base) nogil
        CryptoContext* newCryptoContextForSSRC(uint32_t ssrc, int roc, int64_t keyDerivRate) nogil

cdef extern from "srtp/CryptoContextCtrl.h":

# All definitions.
# From top --> bottom.
    
    cdef cppclass CryptoContextCtrl:
        CryptoContextCtrl(uint32_t ssrc,
                          const  int32_t ealg,
                          const  int32_t aalg,
                          uint8_t* masterKey,
                          int32_t  masterKeyLength,
                          uint8_t* masterSalt,
                          int32_t  masterSaltLength,
                          int32_t  ekeyl,
                          int32_t  akeyl,
                          int32_t  skeyl,
                          int32_t  tagLength) nogil
        void     srtcpEncrypt(uint8_t* rtp, int32_t len, uint32_t index, uint32_t ssrc) nogil
        void     srtcpAuthenticate(uint8_t* rtp, int32_t len, uint32_t index, uint8_t* tag) nogil
        void     deriveSrtcpKeys() nogil
        bool     checkReplay(uint32_t newSeqNumber) nogil
        void     update(uint32_t newSeqNumber) nogil
        int32_t  getTagLength() nogil
        int32_t  getMkiLength() nogil
        uint32_t getSsrc() nogil
        uint32_t getSrtcpIndex() nogil
        void     setSrtcpIndex(uint32_t index) nogil
        void     setLabelbase(uint8_t base) nogil
        CryptoContextCtrl* newCryptoContextForSSRC(uint32_t ssrc) nogil
        
cdef extern from "srtp/SrtpHandler.h" namespace "SrtpHandler":

# All definitions.
# From top --> bottom.
# using namespace to call static class function ...
     
    bool    protect(CryptoContext* pcc, uint8_t* buffer, size_t length, size_t* newLength) nogil
    int32_t unprotect(CryptoContext* pcc, uint8_t* buffer, size_t length, size_t* newLength, SrtpErrorData* errorData) nogil
    bool    protectCtrl(CryptoContextCtrl* pcc, uint8_t* buffer, size_t length, size_t* newLength) nogil
    int32_t unprotectCtrl(CryptoContextCtrl* pcc, uint8_t* buffer, size_t length, size_t* newLength) nogil
