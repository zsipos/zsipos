# SPDX-FileCopyrightText: 2019 Stefan Adams <stefan.adams@vipcomag.de
# SPDX-License-Identifier: GPL-3.0-or-later

"""
Copyright (C) 2019 Stefan Adams

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

print("starting...") # nohup.out

import os

# process pid ASAP
try:
    with open('/var/run/zsipos.pid', 'w') as f:
        f.write(str(os.getpid()))
except:
    pass

from console import console
console.info("starting...") 

# import is very slow in box
console.info("importing...")
from sys import argv, exit, exc_info
from getopt import getopt, GetoptError
import logging
import socket
console.info("still importing...")
from utils import loadmodule, showversion
from iputils import get_ip_address, get_default_gateway_linux, split_host_port
from config import config
import consts
from Exceptions import ZsiposException, ZsiposCfgException
console.info("import completed")

log = logging.getLogger("zsipos")
cfggui = False

def infomsg(msg):
    log.info(msg)
    console.info(msg)

def usage():
    print("usage:", argv[0], "[-h|--help] [-v} [--config configfile] [--logile logfile] [--logext] [--logloc] [--no-gui]")

def setExternalPhoneAddress():
    if config.has_option(consts.SECTION, consts.EXTPHONEADDR):
        extphoneadr = config.get(consts.SECTION, consts.EXTPHONEADDR)
        if len(extphoneadr.strip()):
            return
    try:
        extphoneadr = get_ip_address("eth0")
        if extphoneadr == "0.0.0.0":
            raise ZsiposCfgException("DHCP error")
    except:
        raise ZsiposCfgException("ip address eth0 not found")
    config.set(consts.SECTION, consts.EXTPHONEADDR, extphoneadr)

def setExternalProxyAddress():
    try:
        sipproxy = config.get(consts.SECTION, consts.SIPPROXY).strip()
    except:
        raise ZsiposCfgException("sipproxy not found")
    if len(sipproxy):
        sipparams = split_host_port(sipproxy)
        try:
            extproxyadr = socket.gethostbyname(sipparams[0])
        except:
            raise ZsiposCfgException("sipproxy invalid hostname")
        config.set(consts.SECTION, consts.EXTPROXYADDR, extproxyadr)
        if len(sipparams) == 2 and len(sipparams[1]):
            config.set(consts.SECTION, consts.EXTPROXYPORT, sipparams[1])
        else:
            extproxyport = config.get(consts.SECTION, consts.EXTPROXYPORT).strip()
            config.set(consts.SECTION, consts.SIPPROXY, "%s:%s" %(sipproxy, extproxyport))
    else:
        raise ZsiposCfgException("sipproxy not found")

def setExternalGateway():
    if config.has_option(consts.SECTION, consts.EXTGATEWAY):
        return
    try: 
        gateway = get_default_gateway_linux()
    except:
        raise ZsiposCfgException("dhcp gateway not found")
    if not gateway:
        raise ZsiposCfgException("external gateway not found")

    log.info("gateway " + gateway)
    config.set(consts.SECTION, consts.EXTGATEWAY, gateway)
    

def app_main(withgui):

    try:

        infomsg('loading TWISTED subsystem')
        from twisted.internet import reactor
        from twisted.logger import STDLibLogObserver, globalLogBeginner  
        
        # redirect twisted logging to python logging
        globalLogBeginner.beginLoggingTo([STDLibLogObserver()])
        
        infomsg('starting application.')
        
        # DHCP, DNS: find missing addresses
        setExternalPhoneAddress()
        setExternalGateway()
        setExternalProxyAddress()

        try:
            #force exception if not found
            config.get(consts.SECTION, consts.EXTPHONEADDR)
            config.get(consts.SECTION, consts.LOCPROXYADDR)
            config.get(consts.SECTION, consts.EXTGATEWAY)
            config.get(consts.SECTION, consts.EXTPROXYADDR)
        except:
            raise ZsiposCfgException("wrong or missing parameter")

        import rtp
        rtp.init() # @UndefinedVariable

        if withgui:
            def thread_init_cb():
                rtp.register_gui_thread() # @UndefinedVariable                
            import gui
            gui.init(thread_init_cb) # @UndefinedVariable

        log.info("loading SIP subsystem")
        import GMITM
        gmitm = GMITM.GMITM() 
        if withgui:
            gmitm.setEventSink(gui.GUI_GMITMEventListener()) # @UndefinedVariable
        log.info("GMITM created.")

        reactor.callLater(1, rtp.postinit)          # @UndefinedVariable
        reactor.run(installSignalHandlers = True)   # @UndefinedVariable

    finally:
        try:
            gui.close() # @UndefinedVariable
        except:
            pass
        try:
            rtp.close() # @UndefinedVariable
        except:
            pass

def cfg_main(infstr):
    import gui
    gui.cfg_main(infstr) # @UndefinedVariable

def main_func():
    global cfggui
    # TODO: still needed? Set the rlimits
    # resource.setrlimit(resource.RLIMIT_DATA, (2*1024*1024, resource.RLIM_INFINITY))    

    # Set some defaults here.    
    configfile = consts.CFGFILE
    logfile = None
    logext  = False
    logloc  = False
    withgui = True
    cfggui  = False

    try:
        opts, _ = getopt(argv[1:], "hv", ["help", "config=", "logfile=", "logext", "logloc", "no-gui", "cfg-gui"])
    except GetoptError as err:
        # print help information and exit:
        errmsg = str(err)  # will print something like "option -a not recognized"
        print(errmsg)
        console.info(errmsg)
        usage()
        exit(2)
    for o, a in opts:
        if o == "--config":
            configfile = a
        elif o in ["-?", "-h", "--help"]:
            usage()
            exit(2)

        elif o == "--no-gui":
            log.debug("gui disabled.")
            withgui = False
        elif o == "--cfg-gui":
            cfggui = True
        elif o == '--logfile':
            logfile = a
        elif o == "--logext":
            logext = True
        elif o == "--logloc":
            logloc = True
        elif o == '-v':
            showversion()
            exit()
        else:
            assert False, "unhandled option"

    logging.basicConfig(format="%(asctime)s.%(msecs).3d:%(thread)d:%(levelname)s:%(name)s:%(message)s", 
                        datefmt="%d.%m.%Y %H:%M:%S", level=logging.DEBUG, filename=logfile) # maxBytes=1024*1024, backupCount=7)

    #config defaults
    infstr = ""

    try:
        config.read([configfile])
    except:
        # find a valid config
        logerrorexception()
        cfggui = True
        infstr = "invalid configfile"
        os.unlink(configfile)
        if os.path.isfile(consts.CFGFILEBAK) and os.path.getsize(consts.CFGFILEBAK):
            os.system("cp %s %s" % (consts.CFGFILEBAK, consts.CFGFILE))
            infstr +=  ", restored from %s" % (consts.CFGFILEBAK)
        else:
            os.system("cp %s %s" % (consts.CFGFILEFACTORY, consts.CFGFILE))
            infstr +=  ", restored from %s" % (consts.CFGFILEFACTORY)
        # try again - or fail
        config.read([configfile])

    if logext:
        config.set(consts.SECTION, consts.LOGEXT, "True")
    if logloc:
        config.set(consts.SECTION, consts.LOGLOC, "True")

    infomsg("loading RTP subsystem")
    loadmodule("rtp")
    if withgui or cfggui:
        infomsg("loading GUI subsystem")
        loadmodule("gui")

    if cfggui:
        cfg_main(infstr)
    else:
        try:
            app_main(withgui)
        except ZsiposException as e:
            if withgui:
                cfg_main(str(exc_info()[1]))
            else:
                raise e

def logerrorcaused_by(e):
    if hasattr(e, "caused_by"):
        log.error("CAUSED BY: %s", e.caused_by[1], exc_info = e.caused_by)
        logerrorcaused_by(e.caused_by[1])

def logerrorexception():
    info = exc_info()
    log.error("EXCEPTION: %s", info[1], exc_info=info)
    logerrorcaused_by(info[1])

########
# MAIN #
########

if __name__ == '__main__':
    try:
        main_func()
    #catch your exceptions here...
    except KeyboardInterrupt:
        exit(0)
    except:
        logerrorexception()
        print(exc_info()[1]) # show in nohup.out
        if cfggui:
            console.info(str(exc_info()[1]))
            exit(99)
        exit(1)
