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

cdef extern from "libzrtpcpp/ZrtpTextData.h":
    cdef char clientId[]
    
cdef extern from "libzrtpcpp/zrtpPacket.h":
    ctypedef struct HelloAckPacket_t:
        pass

cdef extern from "libzrtpcpp/ZrtpCWrapper.h":

#
# All definitions.
# From top --> bottom.
#

    cdef int Responder
    cdef int Initiator
    
    cdef int CRC_SIZE
    cdef int ZRTP_MAGIC
    cdef int MAX_ZRTP_SIZE
    
    ctypedef enum zrtp_MessageSeverity:
        zrtp_Info,
        zrtp_Warning,
        zrtp_Severe,
        zrtp_ZrtpError

    ctypedef enum zrtp_InfoCodes:
        zrtp_InfoHelloReceived,
        zrtp_InfoCommitDHGenerated,
        zrtp_InfoRespCommitReceived,
        zrtp_InfoDH1DHGenerated,
        zrtp_InfoInitDH1Received,
        zrtp_InfoRespDH2Received,
        zrtp_InfoInitConf1Received,
        zrtp_InfoRespConf2Received,
        zrtp_InfoRSMatchFound,
        zrtp_InfoSecureStateOn,
        zrtp_InfoSecureStateOff

    ctypedef enum zrtp_WarningCodes:
        zrtp_WarningDHAESmismatch,
        zrtp_WarningGoClearReceived,
        zrtp_WarningDHShort,
        zrtp_WarningNoRSMatch,
        zrtp_WarningCRCmismatch,
        zrtp_WarningSRTPauthError,
        zrtp_WarningSRTPreplayError,
        zrtp_WarningNoExpectedRSMatch,
        zrtp_WarningNoExpectedAuxMatch
        
    ctypedef enum zrtp_SevereCodes:
        zrtp_SevereHelloHMACFailed,
        zrtp_SevereCommitHMACFailed,
        zrtp_SevereDH1HMACFailed,
        zrtp_SevereDH2HMACFailed,
        zrtp_SevereCannotSend,
        zrtp_SevereProtocolError,
        zrtp_SevereNoTimer,
        zrtp_SevereTooMuchRetries

    ctypedef enum zrtp_ZrtpErrorCodes:
        zrtp_MalformedPacket,
        zrtp_CriticalSWError,
        zrtp_UnsuppZRTPVersion,
        zrtp_HelloCompMismatch,
        zrtp_UnsuppHashType,
        zrtp_UnsuppCiphertype,
        zrtp_UnsuppPKExchange,
        zrtp_UnsuppSRTPAuthTag,
        zrtp_UnsuppSASScheme,
        zrtp_NoSharedSecret,
        zrtp_DHErrorWrongPV,
        zrtp_DHErrorWrongHVI,
        zrtp_SASuntrustedMiTM,
        zrtp_ConfirmHMACWrong,
        zrtp_NonceReused,
        zrtp_EqualZIDHello,
        zrtp_GoCleatNotAllowed,
        zrtp_IgnorePacket

    ctypedef enum zrtp_InfoEnrollment:
        zrtp_EnrollmentRequest,
        zrtp_EnrollmentCanceled,
        zrtp_EnrollmentFailed,
        zrtp_EnrollmentOk

    ctypedef enum zrtpStates:
        Initial,
        Detect,
        AckDetected,
        AckSent,
        WaitCommit,
        CommitSent,
        WaitDHPart2,
        WaitConfirm1,
        WaitConfirm2,
        WaitConfAck,
        WaitClearAck,
        SecureState,
        WaitErrorAck,
        numberOfStates

    ctypedef enum zrtp_SrtpAlgorithms:
        zrtp_Aes,
        zrtp_TwoFish,
        zrtp_Sha1,
        zrtp_Skein

    ctypedef struct C_SrtpSecret_t: 
        zrtp_SrtpAlgorithms symEncAlgorithm
        const uint8_t*      keyInitiator
        int32_t             initKeyLen
        const uint8_t*      saltInitiator
        int32_t             initSaltLen
        const uint8_t*      keyResponder
        int32_t             respKeyLen
        const uint8_t*      saltResponder
        int32_t             respSaltLen
        zrtp_SrtpAlgorithms authAlgorithm
        int32_t             srtpAuthTagLen
        char*               sas
        int32_t             role

    cdef int ForReceiver
    cdef int ForSender

    ctypedef struct ZRtp:
        pass
    
    ctypedef struct ZrtpCallbackWrapper:
        pass
    
    ctypedef struct ZrtpConfigure:
        pass

    ctypedef struct ZrtpContext:
        ZRtp*                zrtpEngine
        ZrtpCallbackWrapper* zrtpCallback
        ZrtpConfigure*       configure
        ZRtp*                zrtpMaster
        void*                userData

    ctypedef struct zrtp_Callbacks:
        int32_t (*zrtp_sendDataZRTP) (ZrtpContext* ctx, const uint8_t* data, int32_t length)
        int32_t (*zrtp_activateTimer) (ZrtpContext* ctx, int32_t time)
        int32_t (*zrtp_cancelTimer)(ZrtpContext* ctx)
        void    (*zrtp_sendInfo) (ZrtpContext* ctx, int32_t severity, int32_t subCode)
        int32_t (*zrtp_srtpSecretsReady) (ZrtpContext* ctx, C_SrtpSecret_t* secrets, int32_t part)
        void    (*zrtp_srtpSecretsOff) (ZrtpContext* ctx, int32_t part)
        void    (*zrtp_rtpSecretsOn) (ZrtpContext* ctx, char* c, char* s, int32_t verified)
        void    (*zrtp_handleGoClear)(ZrtpContext* ctx)
        void    (*zrtp_zrtpNegotiationFailed) (ZrtpContext* ctx, int32_t severity, int32_t subCode)
        void    (*zrtp_zrtpNotSuppOther)(ZrtpContext* ctx)
        void    (*zrtp_synchEnter)(ZrtpContext* ctx)
        void    (*zrtp_synchLeave)(ZrtpContext* ctx)
        void    (*zrtp_zrtpAskEnrollment) (ZrtpContext* ctx, int32_t info)
        void    (*zrtp_zrtpInformEnrollment) (ZrtpContext* ctx, int32_t info)
        void    (*zrtp_signSAS)(ZrtpContext* ctx, uint8_t* sas)
        int32_t (*zrtp_checkSASSignature) (ZrtpContext* ctx, uint8_t* sas)

    cdef ZrtpContext* zrtp_CreateWrapper() nogil
    cdef void zrtp_initializeZrtpEngine(ZrtpContext* zrtpContext,
                                        zrtp_Callbacks *cb,
                                        const char* id,
                                        const char* zidFilename,
                                        void* userData,
                                        int32_t mitmMode) nogil
    cdef void           zrtp_DestroyWrapper (ZrtpContext* zrtpContext) nogil
    cdef int32_t        zrtp_CheckCksum(uint8_t* buffer, uint16_t length, uint32_t crc) nogil
    cdef uint32_t       zrtp_GenerateCksum(uint8_t* buffer, uint16_t length) nogil
    cdef uint32_t       zrtp_EndCksum(uint32_t crc) nogil
    cdef void           zrtp_startZrtpEngine(ZrtpContext* zrtpContext) nogil
    cdef void           zrtp_stopZrtpEngine(ZrtpContext* zrtpContext) nogil
    cdef void           zrtp_processZrtpMessage(ZrtpContext* zrtpContext, uint8_t *extHeader, uint32_t peerSSRC, size_t length) nogil
    cdef void           zrtp_processTimeout(ZrtpContext* zrtpContext) nogil
    cdef int32_t        zrtp_handleGoClear(ZrtpContext* zrtpContext, uint8_t *extHeader) nogil
    cdef void           zrtp_setAuxSecret(ZrtpContext* zrtpContext, uint8_t* data, int32_t length) nogil
    cdef int32_t        zrtp_inState(ZrtpContext* zrtpContext, int32_t state) nogil
    cdef void           zrtp_SASVerified(ZrtpContext* zrtpContext) nogil
    cdef void           zrtp_resetSASVerified(ZrtpContext* zrtpContext) nogil
    cdef char*          zrtp_getHelloHash(ZrtpContext* zrtpContext, int32_t index) nogil
    cdef char*          zrtp_getPeerHelloHash(ZrtpContext* zrtpContext) nogil
    cdef char*          zrtp_getMultiStrParams(ZrtpContext* zrtpContext, int32_t *length) nogil
    cdef void           zrtp_setMultiStrParams(ZrtpContext* zrtpContext, char* parameters, int32_t length, ZrtpContext* master) nogil
    cdef int32_t        zrtp_isMultiStream(ZrtpContext* zrtpContext) nogil
    cdef int32_t        zrtp_isMultiStreamAvailable(ZrtpContext* zrtpContext) nogil
    cdef void           zrtp_acceptEnrollment(ZrtpContext* zrtpContext, int32_t accepted) nogil
    cdef int32_t        zrtp_isEnrollmentMode(ZrtpContext* zrtpContext) nogil
    cdef void           zrtp_setEnrollmentMode(ZrtpContext* zrtpContext, int32_t enrollmentMode) nogil
    cdef int32_t        isPeerEnrolled(ZrtpContext* zrtpContext) nogil
    cdef int32_t        zrtp_sendSASRelayPacket(ZrtpContext* zrtpContext, uint8_t* sh, char* render) nogil
    cdef const char*    zrtp_getSasType(ZrtpContext* zrtpContext) nogil
    cdef uint8_t*       zrtp_getSasHash(ZrtpContext* zrtpContext) nogil
    cdef int32_t        zrtp_setSignatureData(ZrtpContext* zrtpContext, uint8_t* data, int32_t length) nogil
    cdef const uint8_t* zrtp_getSignatureData(ZrtpContext* zrtpContext) nogil
    cdef int32_t        zrtp_getSignatureLength(ZrtpContext* zrtpContext) nogil
    cdef void           zrtp_conf2AckSecure(ZrtpContext* zrtpContext) nogil
    cdef int32_t        zrtp_getPeerZid(ZrtpContext* zrtpContext, uint8_t* data) nogil
    cdef int32_t        zrtp_getNumberSupportedVersions(ZrtpContext* zrtpContext) nogil
    cdef int32_t        zrtp_getCurrentProtocolVersion(ZrtpContext* zrtpContext) nogil
    
    ctypedef enum Zrtp_AlgoTypes: 
        zrtp_HashAlgorithm, 
        zrtp_CipherAlgorithm, 
        zrtp_PubKeyAlgorithm, 
        zrtp_SasType, 
        zrtp_AuthLength
        
    cdef int32_t     zrtp_InitializeConfig (ZrtpContext* zrtpContext) nogil
    cdef char**      zrtp_getAlgorithmNames(ZrtpContext* zrtpContext, Zrtp_AlgoTypes type) nogil
    cdef void        zrtp_freeAlgorithmNames(char** names) nogil
    cdef void        zrtp_setStandardConfig(ZrtpContext* zrtpContext) nogil
    cdef void        zrtp_setMandatoryOnly(ZrtpContext* zrtpContext) nogil
    cdef void        zrtp_confClear(ZrtpContext* zrtpContext) nogil
    cdef int32_t     zrtp_addAlgo(ZrtpContext* zrtpContext, Zrtp_AlgoTypes algoType, const char* algo) nogil
    cdef int32_t     zrtp_addAlgoAt(ZrtpContext* zrtpContext, Zrtp_AlgoTypes algoType, const char* algo, int32_t index) nogil
    cdef int32_t     zrtp_removeAlgo(ZrtpContext* zrtpContext, Zrtp_AlgoTypes algoType, const char* algo) nogil
    cdef int32_t     zrtp_getNumConfiguredAlgos(ZrtpContext* zrtpContext, Zrtp_AlgoTypes algoType) nogil
    cdef const char* zrtp_getAlgoAt(ZrtpContext* zrtpContext, Zrtp_AlgoTypes algoType, int32_t index) nogil
    cdef int32_t     zrtp_containsAlgo(ZrtpContext* zrtpContext, Zrtp_AlgoTypes algoType, const char*  algo) nogil
    cdef void        zrtp_setTrustedMitM(ZrtpContext* zrtpContext, int32_t yesNo) nogil
    cdef int32_t     zrtp_isTrustedMitM(ZrtpContext* zrtpContext) nogil
    cdef void        zrtp_setSasSignature(ZrtpContext* zrtpContext, int32_t yesNo) nogil
    cdef int32_t     zrtp_isSasSignature(ZrtpContext* zrtpContext) nogil
    
cdef extern from "libzrtpcpp/ZrtpCodes.h":
    cdef int RTP_HEADER_LENGTH

    ctypedef enum SrtpErrorType:
        DecodeError,
        ReplayError,
        AuthError
        
    ctypedef struct SrtpErrorData:
        SrtpErrorType  errorType
        uint32_t      *rtpHeader #[RTP_HEADER_LENGTH / sizeof(uint32_t)];
        size_t         length
        uint64_t       guessedIndex

cdef extern from "libzrtpcpp/ZrtpSdesStream.h":

#
# All definitions.
# From top --> bottom.
#
    cdef int MAX_KEY_LEN
    cdef int MAX_SALT_LEN
    cdef int MAX_DIGEST_LENGTH
    cdef int MAX_CRYPT_STRING_LEN

    ctypedef enum sdesSuites:
        AES_CM_128_HMAC_SHA1_32,
        AES_CM_128_HMAC_SHA1_80

    ctypedef enum sdesZrtpStates:
        STREAM_INITALIZED,
        OUT_PROFILE_READY,
        IN_PROFILE_READY,
        SDES_SRTP_ACTIVE

    ctypedef enum sdesHmacTypeMix:
        MIX_NONE,
        MIX_HMAC_SHA,
        MIX_MAC_SKEIN

    cdef cppclass ZrtpSdesStream:
        ZrtpSdesStream(const sdesSuites suite = AES_CM_128_HMAC_SHA1_32) nogil
        void            close() nogil
        bool            createSdes(char *cryptoString, size_t *maxLen, bool sipInvite) nogil
        bool            parseSdes(const char *cryptoString, size_t length, bool sipInvite) nogil
        int             getCryptoMixAttribute(char *algoNames, size_t length) nogil
        bool            setCryptoMixAttribute(const char *algoNames) nogil
        bool            outgoingRtp(uint8_t *packet, size_t length, size_t *newLength) nogil
        bool            outgoingRtcp(uint8_t *packet, size_t length, size_t *newLength) nogil
        int             incomingRtp(uint8_t *packet, size_t length, size_t *newLength, SrtpErrorData* errorData=NULL) nogil
        int             incomingSrtcp(uint8_t *packet, size_t length, size_t *newLength) nogil
        bool            outgoingZrtpTunnel(uint8_t *packet, size_t length, size_t *newLength) nogil
        int             incomingZrtpTunnel(uint8_t *packet, size_t length, size_t *newLength, SrtpErrorData* errorData=NULL) nogil
        sdesZrtpStates  getState() nogil
        sdesHmacTypeMix getHmacTypeMix() nogil
        const char*     getCipher() nogil
        const char*     getAuthAlgo() nogil

cdef extern from "cryptcommon/ZrtpRandom.h":

#
# All definitions.
# From top --> bottom.
#
    cdef int zrtp_AddEntropy(const uint8_t *buffer, uint32_t length)
    cdef int zrtp_getRandomData(uint8_t *buffer, uint32_t length)

