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

DEFAULTPORT = 5060

#section for config file
SECTION = "gmitm"

#The name of the interfaces
EXTIFNAME = "eth0"
LOCIFNAME = "eth1"

#options for config file
SIPPROXY     = "sipProxy" # get resolved to EXTPROXYADDR, EXTPROXYPORT
EXTPHONEADDR = "externalPhoneAddress"
EXTPHONEPORT = "externalPhonePort"
EXTPROXYADDR = "externalProxyAddress"
EXTPROXYPORT = "externalProxyPort"
EXTGATEWAY   = "externalGateway"
EXTNETMASK   = "externalNetmask"
EXTUSEDHCP   = "externalUseDHCP"
LOCPROXYADDR = "localProxyAddress"
LOCPROXYPORT = "localProxyPort"
LOCNETMASK   = "localNetmask"
#logging ..
LOGEXT = "logExternal"
LOGLOC = "logLocal"
LOGFULLMESSAGE = "logFullMessage"
LOGCCEVENTS = "logCCEvents"
LOGCCMESSAGES = "logCCMessages"
LOGBMEVENTS = "logBMEvents"
LOGSIPTIMING = "logSipProcessingTime"
LOGTIMERS = "logTimers"
SIPDELAY = "sipDebugDelay"
LOGZRTPCB = "logZrtpEvents"
LOGZSESSIONCB = "logZSessionEvents"
LOGICE = "logICE"
LOGDTMF = "logDTMF"
PJLOGLEVEL = "pjLogLevel"
#timers
TIMER1 = "timer1"
TIMER4 = "timer4"
TIMERB = "timerB"
TIMERC = "timerC"
TIMERD = "timerD"
TIMERF = "timerF"
TIMERK = "timerK"
TIMERS = "timerS"
#icestorage
ICESTORAGEURL = "iceStorageUrl"
DNSSERVER = "dnsServer"
STUNSERVER = "stunServer"
TURNSERVER = "turnServer"
TURNUSER = "turnUser"
TURNPASSWORD = "turnPassword"
NTPSERVER = "ntpServer"
UPLOADSERVER="uploadServer"
UPLOADPORT="uploadPort"
UPLOADUSER="uploadUser"
UPLOADID= "uploadId"
#gui
ICONDIR = "iconDirectory"
#misc 
SKIPZRTP1 = "skipZrtp1"

#files
CFGFILE = "zsipos.cfg"
CFGFILEBAK = "zsipos.cfg.bak"
CFGFILEFACTORY = "zsipos_factory.cfg"
ZIDFILE = "zsipos.zid"
NDBFILE = "zsipos.ndb"
