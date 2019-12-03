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
# we want to override enum names / DEF names for python usage
#
module = modules[__name__]

def assign(name, val):
    setattr(module, name, val)

zrtp_Info = zrtp.zrtp_Info
zrtp_Warning = zrtp.zrtp_Warning
zrtp_Severe = zrtp.zrtp_Severe
zrtp_ZrtpError = zrtp.zrtp_ZrtpError

zrtp_MessageSeverity_names = [ None, "Info", "Warning", "Servere", "ZrtpError" ]

zrtp_InfoHelloReceived = zrtp.zrtp_InfoHelloReceived
zrtp_InfoCommitDHGenerated = zrtp.zrtp_InfoCommitDHGenerated
zrtp_InfoRespCommitReceived = zrtp.zrtp_InfoRespCommitReceived
zrtp_InfoDH1DHGenerated = zrtp.zrtp_InfoDH1DHGenerated
zrtp_InfoInitDH1Received = zrtp.zrtp_InfoInitDH1Received
zrtp_InfoRespDH2Received = zrtp.zrtp_InfoRespDH2Received
zrtp_InfoInitConf1Received = zrtp.zrtp_InfoInitConf1Received
zrtp_InfoRespConf2Received = zrtp.zrtp_InfoRespConf2Received
zrtp_InfoRSMatchFound = zrtp.zrtp_InfoRSMatchFound
zrtp_InfoSecureStateOn = zrtp.zrtp_InfoSecureStateOn
zrtp_InfoSecureStateOff = zrtp.zrtp_InfoSecureStateOff

zrtp_InfoCodes_names = [ None, "InfoHelloReceived", "InfoCommitDHGenerated", "InfoRespCommitReceived",
                        "InfoDH1DHGenerated", "InfoInitDH1Received", "InfoRespDH2Received", "InfoInitConf1Received",
                        "InfoRespConf2Received", "InfoRSMatchFound", "InfoSecureStateOn", "InfoSecureStateOff" ]

zrtp_WarningDHAESmismatch = zrtp.zrtp_WarningDHAESmismatch
zrtp_WarningGoClearReceived = zrtp.zrtp_WarningGoClearReceived
zrtp_WarningDHShort = zrtp.zrtp_WarningDHShort
zrtp_WarningNoRSMatch = zrtp.zrtp_WarningNoRSMatch
zrtp_WarningCRCmismatch = zrtp.zrtp_WarningCRCmismatch
zrtp_WarningSRTPauthError = zrtp.zrtp_WarningSRTPauthError
zrtp_WarningSRTPreplayError = zrtp.zrtp_WarningSRTPreplayError
zrtp_WarningNoExpectedRSMatch = zrtp.zrtp_WarningNoExpectedRSMatch
zrtp_WarningNoExpectedAuxMatch = zrtp.zrtp_WarningNoExpectedAuxMatch

zrtp_WarningCodes_names = [ None, "WarningDHAESmismatch","WarningGoClearReceived", "WarningDHShort", 
                           "WarningNoRSMatch", "WarningCRCmismatch", "WarningSRTPauthError", 
                           "WarningSRTPreplayError", "WarningNoExpectedRSMatch", "WarningNoExpectedAuxMatch" ]

zrtp_SevereHelloHMACFailed = zrtp.zrtp_SevereHelloHMACFailed
zrtp_SevereCommitHMACFailed = zrtp.zrtp_SevereCommitHMACFailed
zrtp_SevereDH1HMACFailed = zrtp.zrtp_SevereDH1HMACFailed
zrtp_SevereDH2HMACFailed = zrtp.zrtp_SevereDH2HMACFailed
zrtp_SevereCannotSend = zrtp.zrtp_SevereCannotSend
zrtp_SevereProtocolError = zrtp.zrtp_SevereProtocolError
zrtp_SevereNoTimer = zrtp.zrtp_SevereNoTimer
zrtp_SevereTooMuchRetries = zrtp.zrtp_SevereTooMuchRetries

zrtp_SevereCodes_names = [ None, "SevereHelloHMACFailed", "SevereCommitHMACFailed", "SevereDH1HMACFailed", 
                          "SevereDH2HMACFailed", "SevereCannotSend", "SevereProtocolError", 
                          "SevereNoTimer", "SevereTooMuchRetries" ]

zrtp_MalformedPacket = zrtp.zrtp_MalformedPacket
zrtp_CriticalSWError = zrtp.zrtp_CriticalSWError
zrtp_UnsuppZRTPVersion = zrtp.zrtp_UnsuppZRTPVersion
zrtp_HelloCompMismatch = zrtp.zrtp_HelloCompMismatch
zrtp_UnsuppHashType = zrtp.zrtp_UnsuppHashType
zrtp_UnsuppCiphertype = zrtp.zrtp_UnsuppCiphertype
zrtp_UnsuppPKExchange = zrtp.zrtp_UnsuppPKExchange
zrtp_UnsuppSRTPAuthTag = zrtp.zrtp_UnsuppSRTPAuthTag
zrtp_UnsuppSASScheme = zrtp.zrtp_UnsuppSASScheme
zrtp_NoSharedSecret = zrtp.zrtp_NoSharedSecret
zrtp_DHErrorWrongPV = zrtp.zrtp_DHErrorWrongPV
zrtp_DHErrorWrongHVI = zrtp.zrtp_DHErrorWrongHVI
zrtp_SASuntrustedMiTM = zrtp.zrtp_SASuntrustedMiTM
zrtp_ConfirmHMACWrong = zrtp.zrtp_ConfirmHMACWrong
zrtp_NonceReused = zrtp.zrtp_NonceReused
zrtp_EqualZIDHello = zrtp.zrtp_EqualZIDHello
zrtp_GoCleatNotAllowed = zrtp.zrtp_GoCleatNotAllowed
zrtp_IgnorePacket = zrtp.zrtp_IgnorePacket

cdef int _zrtp_NotSupported
_zrtp_NotSupported = 0
zrtp_NotSupported = _zrtp_NotSupported
        
zrtp_ZrtpErrorCodes_names = {   zrtp_MalformedPacket : "MalformedPacket", zrtp_CriticalSWError : "CriticalSWError",
                                zrtp_UnsuppZRTPVersion : "UnsuppZRTPVersion", zrtp_HelloCompMismatch : "HelloCompMismatch",
                                zrtp_UnsuppHashType : "UnsuppHashType", zrtp_UnsuppCiphertype : "UnsuppCiphertype",
                                zrtp_UnsuppPKExchange : "UnsuppPKExchange", zrtp_UnsuppSRTPAuthTag : "UnsuppSRTPAuthTag",
                                zrtp_UnsuppSASScheme : "UnsuppSASScheme", zrtp_NoSharedSecret : "NoSharedSecret", 
                                zrtp_DHErrorWrongPV : "DHErrorWrongPV", zrtp_DHErrorWrongHVI : "DHErrorWrongHVI",
                                zrtp_SASuntrustedMiTM : "SASuntrustedMiTM", zrtp_ConfirmHMACWrong : "ConfirmHMACWrong",
                                zrtp_NonceReused : "NonceReused", zrtp_EqualZIDHello : "EqualZIDHello",
                                zrtp_GoCleatNotAllowed : "GoCleatNotAllowed", zrtp_IgnorePacket : "(zrtp_IgnorePacket)",
                                zrtp_NotSupported : "NotSupported"     }

zrtp_SeveritySubCode_names = [ None, zrtp_InfoCodes_names, zrtp_WarningCodes_names, zrtp_SevereCodes_names, zrtp_ZrtpErrorCodes_names ]    

zrtp_EnrollmentRequest = zrtp.zrtp_EnrollmentRequest
zrtp_EnrollmentCanceled = zrtp.zrtp_EnrollmentCanceled
zrtp_EnrollmentFailed = zrtp.zrtp_EnrollmentFailed
zrtp_EnrollmentOk = zrtp.zrtp_EnrollmentOk

zrtp_InfoEnrollment_names = [ "EnrollmentRequest", "EnrollmentCanceled", "EnrollmentFailed", "EnrollmentOk" ]

zrtp_Aes = zrtp.zrtp_Aes
zrtp_TwoFish = zrtp.zrtp_TwoFish
zrtp_Sha1 = zrtp.zrtp_Sha1
zrtp_Skein = zrtp.zrtp_Skein

zrtp_SrtpAlgorithms_names = [ None, "aes", "twofish", "sha1", "skein" ]

assign("ZRTP_STATE_NONE", ZRTP_STATE_NONE)
assign("ZRTP_STATE_STARTED", ZRTP_STATE_STARTED)
assign("ZRTP_STATE_CONNECTED", ZRTP_STATE_CONNECTED)
assign("ZRTP_STATE_FAILED", ZRTP_STATE_FAILED)

ZrtpState_names = [ None, "started", "connected", "failed" ]
    
assign("ICE_STATE_NONE", ICE_STATE_NONE)
assign("ICE_STATE_STARTED", ICE_STATE_STARTED)
assign("ICE_STATE_CONNECTED", ICE_STATE_CONNECTED)
assign("ICE_STATE_FAILED", ICE_STATE_FAILED)

IceState_names = [ None, "started", "connected", "failed" ]

assign("CRYPTO_STATEINFO_NONE", CRYPTO_STATEINFO_NONE)
assign("CRYPTO_STATEINFO_ZRTP1", CRYPTO_STATEINFO_ZRTP1)
assign("CRYPTO_STATEINFO_LOCAL_OFFER", CRYPTO_STATEINFO_LOCAL_OFFER)
assign("CRYPTO_STATEINFO_DTMF_EXCHANGE", CRYPTO_STATEINFO_DTMF_EXCHANGE)
assign("CRYPTO_STATEINFO_ICE", CRYPTO_STATEINFO_ICE)
assign("CRYPTO_STATEINFO_ZRTP2", CRYPTO_STATEINFO_ZRTP2)
assign("CRYPTO_STATEINFO_CONNECTED", CRYPTO_STATEINFO_CONNECTED)
assign("CRYPTO_STATEINFO_FAILED", CRYPTO_STATEINFO_FAILED) 

