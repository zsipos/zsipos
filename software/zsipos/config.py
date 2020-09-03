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
from configparser import SafeConfigParser
from functools import wraps
from threading import RLock

import consts

class ConfigParser(SafeConfigParser):
    '''
    This is just a thread safe wrapper of the original. 
    '''
    
    def __init__(self, *args, **kwargs):
        SafeConfigParser.__init__(self, *args, **kwargs)
        self.optionxform=str # keep upper case
        self.lock = RLock()
        for member in dir(self):
            if member.startswith("_") or member in ['Lock', 'Unlock']:
                continue
            method = getattr(self, member)
            if callable(method):
                                
                def decorator(func):                    
                    @wraps(func)
                    def locker(*args, **kwargs):
                        self.Lock()
                        try:
                            ret = func(*args, **kwargs)
                            return ret
                        finally:
                            self.Unlock()
                    
                    return locker

                    pass
                
                setattr(self, member, decorator(method))
        self._setDefaults()
    
    def Lock(self):
        self.lock.acquire(True)
        
    def Unlock(self):
        self.lock.release()
        
    def safe_get(self, section, key):
        try:
            return self.get(section, key)
        except:
            return None

    def _setDefaults(self):    
        if not self.has_section(consts.SECTION):
            self.add_section(consts.SECTION)
        self.set(consts.SECTION, consts.EXTPHONEPORT, str(consts.DEFAULTPORT))
        self.set(consts.SECTION, consts.EXTPROXYPORT, str(consts.DEFAULTPORT))
        self.set(consts.SECTION, consts.LOCPROXYPORT, str(consts.DEFAULTPORT))
        #logging
        self.set(consts.SECTION, consts.LOGEXT, "False")
        self.set(consts.SECTION, consts.LOGLOC, "False")
        self.set(consts.SECTION, consts.LOGFULLMESSAGE, "False")
        self.set(consts.SECTION, consts.LOGCCEVENTS, "False")
        self.set(consts.SECTION, consts.LOGCCMESSAGES, "False")
        self.set(consts.SECTION, consts.LOGBMEVENTS, "False")
        self.set(consts.SECTION, consts.LOGSIPTIMING, "False")
        self.set(consts.SECTION, consts.LOGTIMERS, "False")
        self.set(consts.SECTION, consts.SIPDELAY, "False")
        self.set(consts.SECTION, consts.LOGZRTPCB, "False")
        self.set(consts.SECTION, consts.LOGZSESSIONCB, "False")
        self.set(consts.SECTION, consts.LOGICE, "False")
        self.set(consts.SECTION, consts.LOGDTMF, "False")
        self.set(consts.SECTION, consts.PJLOGLEVEL, "1")
        #timeouts
        T1=0.5
        self.set(consts.SECTION, consts.TIMER1, str(T1))
        self.set(consts.SECTION, consts.TIMER4, "5.0")
        self.set(consts.SECTION, consts.TIMERB, str(64*T1))
        self.set(consts.SECTION, consts.TIMERC, str(64*T1)) # rfc: 3min
        self.set(consts.SECTION, consts.TIMERD, "32.0")
        self.set(consts.SECTION, consts.TIMERF, str(64*T1))
        self.set(consts.SECTION, consts.TIMERK, "5.0")
        self.set(consts.SECTION, consts.TIMERS, "7.5")
        #gui
        self.set(consts.SECTION, consts.ICONDIR, "zsipos/gui/icons")
        #misc
        self.set(consts.SECTION, consts.SKIPZRTP1, "False")
                    
config = ConfigParser()

