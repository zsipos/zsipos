# SPDX-FileCopyrightText: 2020, 2021 Esther Bergter <esther.bergter@vipcomag.de>
#
# SPDX-License-Identifier: GPL-3.0-or-later

"""
Copyright (C) 2020, 2021 Esther Bergter

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
# configui.pxi
#
# Author: Esther Bergter
#
# Version 2.0

debuginfo = False

# python modules
import crypt
import errno
import glob
import hashlib
import logging
import os, os.path
import re
import requests
import shutil
import socket
import spwd
from subprocess import CalledProcessError
import subprocess
import sys
from time import sleep, time

# private modules
from iputils import split_host_port
from utils import tstr,issel4

include 'configutils.pxi'       # configedit depends on it
include 'configedit.pxi'
include 'confighelp.pxi'
include 'configkeyboard.pxi'
include 'configmount.pxi'       # logs, update
include 'configsave.pxi'
include 'configsure.pxi'        # update, reset
include 'configtext.pxi'
include 'configuifltk.pxi'
# config groups
include 'config_ip.pxi'
include 'config_server.pxi'
include 'config_logs.pxi'
include 'config_experts.pxi'
include 'config_rootpw.pxi'
include 'config_reset.pxi'
include 'config_sysinfo.pxi'
include 'config_update.pxi'


############################
# globals
cdef CONFIGUI* configui

stable = False          # configui not initialized yet
root_pw_is_set = True   # force pw_reset

""" Callbacks """
# application MAINUI
cdef void on_config_close(Fl_Widget* widget, void *data) with gil:
    configui.window.hide()

# main window
cdef void on_btn_back(Fl_Widget* widget, void *data) with gil:
    configui.btn_warn.hide()
    configui.tab_config.show()
    do_back()

cdef void on_btn_warn(Fl_Widget* widget, void *data) with gil:
    configui.btn_warn.hide()
    configui.btn_back.show()
    configui.tab_config.show()

# Config TabGroup
cdef void on_tab_group(Fl_Widget *widget, void *data) with gil:
    group_init(get_value(configui.tab_config))

cdef void group_init(Fl_Widget *widget):
    """ call group init """
    mytab = <Fl_Tabs*>widget

    ui = configui
    if mytab == ui.group_ip:
        group_ip_init()
    elif mytab == ui.group_server:
        group_server_init()
    elif mytab == ui.group_logs:
        group_logs_init()
    elif mytab == ui.group_experts:
        group_experts_init()
    elif mytab == ui.group_rootpw:
        group_rootpw_init()
    elif mytab == ui.group_reset:
        group_reset_init()
    elif mytab == ui.group_sysinfo:
        group_sysinfo_init()
    elif mytab == ui.group_update:
        group_update_init()
    else:
        raise Exception("group_init: unknown group")

cdef void show_config(Fl_Widget *widget):
    #debug("show_config")
    group_init(widget)
    configui.tab_config.value(widget)
    configui.window.activate()
    configui.btn_back.show()
    configui.btn_back.take_focus()
    configui.window.show()

###########################################################################
# Python
###########################################################################

# Python Functions (alphabetical)
def check_mandatories():
    if consts.EXTUSEDHCP in cfdict and cfdict[consts.EXTUSEDHCP]:
        if 'AutoDns' in cfdict and cfdict['AutoDns']:
            ret = ""
        else:
            ret = check_mandatory_dnsserver()
    else:
        ret = check_mandatory_static_ip()
        ret += check_mandatory_dnsserver()
    if len(ret):
        configui.tab_config.value(configui.group_ip)
        ret += check_mandatory_servers()
    else:
        ret = check_mandatory_servers()
        if len(ret):
            configui.tab_config.value(configui.group_server)
    return ret

def check_mandatory_dnsserver():
    return check_mandatory_value(consts.DNSSERVER)

def check_mandatory_servers():
    ret = check_mandatory_value(consts.SIPPROXY)
    ret += check_mandatory_value(consts.ICESTORAGEURL)
    ret += check_mandatory_value(consts.LOCPROXYADDR)
    return ret

def check_mandatory_static_ip():
    ret = check_mandatory_value(consts.EXTPHONEADDR, title='My Ip Address')
    ret += check_mandatory_value(consts.EXTPHONEPORT)
    ret += check_mandatory_value(consts.EXTNETMASK)
    ret += check_mandatory_value(consts.EXTGATEWAY)
    return ret

def check_mandatory_value(myopt, **kwargs):
    if myopt in cfdict and len(cfdict[myopt]) > 0:
        return ""
    else:
        if 'title' in kwargs:
            title = kwargs['title']
        else:
            title = myopt
        return f'{title} missing. '

def cfg_cleanup():
    """ remove values not to be stored """
    if cfdict[consts.EXTUSEDHCP]:
        #cfdict[consts.EXTPHONEADDR] = "" # NEIN! brauche ich
        cfdict[consts.EXTNETMASK] = ""
        cfdict[consts.EXTGATEWAY] = ""
        if 'AutoDns' in cfdict and cfdict['AutoDns']:
            cfdict[consts.DNSSERVER] = ""
    # Extproxy is stored in Sipproxy
    if consts.EXTPROXYADDR in cfdict:
        del cfdict[consts.EXTPROXYADDR]
        config.remove_option(consts.SECTION, consts.EXTPROXYADDR) 
    if consts.EXTPROXYPORT in cfdict:
        del cfdict[consts.EXTPROXYPORT]
        config.remove_option(consts.SECTION, consts.EXTPROXYPORT)

def cfg_hide_externalPhoneAddress():
    """ remove from config just before writing cfg """
    if cfdict[consts.EXTUSEDHCP]:
        config.remove_option(consts.SECTION, consts.EXTPHONEADDR)

def cfg_restore_externalPhoneAddress():
    """ restore extPhoneAddress after cfg is written """
    if cfdict[consts.EXTUSEDHCP] and consts.EXTPHONEADDR in cfdict:
        config.set(consts.SECTION, consts.EXTPHONEADDR, cfdict[consts.EXTPHONEADDR])

def config_has_changed():
    """ True if cfdict differs from olddict """
    #res = cmp(olddict, cfdict)
    res = olddict != cfdict
    if res:
        log.info("config_has_changed")
        for x in cfdict.keys():
            z = olddict.get(x) == cfdict.get(x)
            if not z:
                log.info("key %s: old=%s, new=%s<<" %(x, olddict.get(x), cfdict.get(x)))
        for x in olddict.keys():
            z = olddict.get(x) == cfdict.get(x)
            if not z:
                log.info("key %s: old=%s, new=%s<<" %(x, olddict.get(x), cfdict.get(x)))
        return True
    else:
        return False

def config_to_dict():
    """ copy config items to private dict """
    global olddict, cfdict
    olddict = dict(config.items('gmitm'))

    # Translate True, False
    for key, value in olddict.items():
        if value == 'True':
            olddict[key] = True
        elif value == 'False':
            olddict[key] = False

    # AutoDns
    if consts.EXTUSEDHCP in olddict and olddict[consts.EXTUSEDHCP]:
        if consts.DNSSERVER in olddict and len(olddict[consts.DNSSERVER]):
            olddict['AutoDns'] = False
        else:
            olddict['AutoDns'] = True
    else:
        olddict['AutoDns'] = False

    cfdict = dict(olddict) # make a copy
    #debug_dict("config_to_dict")
# config_to_dict

def debug(string):
    if not debuginfo: return
    log.info(string)

def debug_dict(string, mydict=None):
    if not debuginfo: return
    debug(string)
    if mydict is None:
        mydict = cfdict
    for key in sorted(mydict.keys()):
        s = '{}: {}'.format(key, mydict[key])
        debug(s)
    debug("end of cfdict..............................")

def dict_to_config():
    """ copy dict items back to config. """

    #debug_dict("dict_to_config")
    config[consts.SECTION] = {}
    for key, value in cfdict.items():
        if key == 'AutoDns' or key == 'BOOT_CURRENT':
            continue
        #debug("dict_to_config: %s=%s" %(key, str(value)))
        if len(str(value)):
            config.set(consts.SECTION, key, str(value))

def do_back():
    debug("do_back")
    missings = check_mandatories()
    #debug("check_mandatories: %s" % (missings, ))
    if len(missings):
        #debug("show warning")
        warn(missings)
        return
    if config_has_changed():
        #debug("config has changed")
        cfg_cleanup()
        res = need_restart()
        configui.window.hide()
        if res is None:
            info = "config has changed"
            show_save(info, res)
        else:
            info = "config has changed, need %s" % (res, )
            log.info(info)
            show_save(info, res)
    else:
        configui.window.hide()

def do_ping(host, ifnr):
    #debug("do_ping: host %s" % (host,))
    out = "ping %s ...\n" % (host,)
    show_help('ping', out)
    try:
        if issel4():
            out = subprocess.check_output(["sel4iptool", "eth"+str(ifnr), "ping", host, "2"], stderr=subprocess.STDOUT, encoding="utf8")
        else:
            out = subprocess.check_output(["/usr/bin/env", "ping", "-c", "2", host], stderr=subprocess.STDOUT, encoding="utf8")
    except CalledProcessError as e:
        if len(e.output):
            out = e.output
        else:
            out = str(sys.exc_info()[1])
    finally:
        append_help(out)

def do_restart(restart_type):
    """ restart application """
    if issel4():
        os.sync()
        console.clear()
        if restart_type == 'reboot':
            console.info("reboot...")
            log.info("reboot system")
            os.system('reboot')
        elif restart_type == 'reconfig':
            console.info("reconfigure...")
            log.info("reconfig system")
            os.system('/etc/init.d/rcK && /etc/init.d/rcS')
            #os.system('reboot') # fuer picotcp
        elif restart_type == 'shutdown':
            console.info("shutdown...")
            log.info("shutdown system")
            os.system('poweroff')
        else:
            console.info("restart...")
            log.info("restart zsipos")
            os._exit(0)
    else:
        if restart_type == 'restart' or restart_type == 'reboot':
            console.info("restart...")
            log.info("restart zsipos")
            os._exit(0)
        else:
            what = f'{restart_type} requested'
            info(f"TestModus {what}")
            log.info(what)

def do_save_cfg():
    dict_to_config()
    cfg_hide_externalPhoneAddress()
    if os.path.isfile(consts.CFGFILEBAK):
        os.unlink(consts.CFGFILEBAK)
    if os.path.isfile(consts.CFGFILE):
        os.rename(consts.CFGFILE, consts.CFGFILEBAK)
    with open(consts.CFGFILE, 'w') as cfgfile:
        config.write(cfgfile)
        log.info("cfgfile saved")
    cfg_restore_externalPhoneAddress()
    if 'BOOT_CURRENT' in olddict: # group_update touched
        write_versioncount()
    os.sync()
    config_to_dict() # refresh memory in case not restarted

def err_to_win(mytext, mywin):
    """ write to log.error and append to window """
    if mytext.endswith('\n'):
        log.error(mytext[:-1])
    else:
        log.error(mytext)
    if stable:
        if mywin == 'help':
            append_help(mytext)
        elif mywin == 'info':
            append_updateinfo(mytext)
        elif mywin == 'progress':
            append_progress(mytext)
        else:
            log.error("err_to_win: unknown window %s" % (mywin, ))
            return

def info(infomessage):
    debug(f'info {infomessage}')
    configui.btn_warn.copy_label(infomessage)
    configui.btn_warn.labelcolor(39)
    configui.tab_config.hide()
    configui.btn_warn.show()

def is_testversion():
    """ look for file testversion """
    if os.path.exists(testversion_path):
        debug('testversion')
        return True
    else:
        return False

def logerrorcaused_by(e):
    if hasattr(e, "caused_by"):
        log.error("CAUSED BY: %s", e.caused_by[1], exc_info = e.caused_by)
        logerrorcaused_by(e.caused_by[1])

def logerrorexception(mybuf):
    info = sys.exc_info()
    err_to_win("EXCEPTION: %s\n" % (info[1]), mybuf)
    logerrorcaused_by(info[1])

def need_restart():
    """ scan cfdict """
    # reconfig has priority
    reconfigs = [consts.DNSSERVER,
                 consts.EXTPHONEADDR, consts.EXTPHONEPORT,
                 consts.EXTNETMASK,
                 consts.NTPSERVER,
                 consts.LOCPROXYADDR, consts.LOCPROXYPORT]
    restarts = [consts.SIPPROXY,
                consts.ICESTORAGEURL,
                consts.STUNSERVER,
                consts.TURNSERVER]
    # change from/to DHCP
    if consts.EXTUSEDHCP in olddict:
        if str(olddict[consts.EXTUSEDHCP]) != str(cfdict[consts.EXTUSEDHCP]):
            log.info(consts.EXTUSEDHCP + " changed")
            return 'reconfig'
    elif consts.EXTUSEDHCP in cfdict and cfdict[consts.EXTUSEDHCP]:
        log.info(consts.EXTUSEDHCP + " activated")
        return 'reconfig'
    # reconfig
    for key in reconfigs:
        # Wenn DHCP gesetzt, ignoriere extPhoneAddr und extPhonePort
        if consts.EXTUSEDHCP in cfdict and cfdict[consts.EXTUSEDHCP]:
            if key == consts.EXTPHONEADDR or key == consts.EXTPHONEPORT:
                continue
        if key in cfdict and (key not in olddict or olddict[key] != cfdict[key]):
            log.info('option %s=%s needs reconfig' % (key, cfdict[key]))
            return 'reconfig'
    # restart
    for key in restarts:
        if key in cfdict and (key not in olddict or olddict[key] != cfdict[key]):
            log.info('option %s=%s needs restart' % (key, cfdict[key]))
            return 'restart'
    # Logsettings
    if log_changed():
        return 'restart'
    log.info("restart not needed")
    return None
# need_restart

def ping_simple(var):
    if var in cfdict and len(cfdict[var]):
        if var == consts.LOCPROXYADDR:
            ifnr = 1
        else:
            ifnr = 0
        do_ping(cfdict[var], ifnr)

def ping_hostp(var):
    ifnr = 0 # not LOCPROXYADDR
    if var in cfdict and len(cfdict[var]):
        (host, port) = split_host_port(cfdict[var])
        if len(host):
            do_ping(host, ifnr=0)# not LOCPROXYADDR

def ping_url(var):
    if var in cfdict and len(cfdict[var]):
        (http, host, port) = split_url(cfdict[var])
        if len(host):
            do_ping(host, ifnr=0)# not LOCPROXYADDR

def ping_url_path(var):
    if var in cfdict and len(cfdict[var]):
        (http, host, port, path) = split_url_path(cfdict[var])
        if len(host):
            do_ping(host, ifnr=0)# not LOCPROXYADDR

def warn(warnmessage):
    debug(f'warn {warnmessage}')
    configui.btn_warn.copy_label(warnmessage)
    configui.btn_warn.labelcolor(88)
    configui.tab_config.hide()
    configui.btn_back.hide()
    configui.btn_warn.show()

def write_versioncount():
    global current_versioncounter
    global alternate_versioncounter

    if str(olddict['BOOT_CURRENT']) != str(cfdict['BOOT_CURRENT']):
        if cfdict['BOOT_CURRENT'] == True:
            current_versioncounter = alternate_versioncounter + 1
            try:
                with open(versioncounter_path, 'w') as f:
                    f.write(str(current_versioncounter))
                    log.info("versioncounter updated")
            except:
                    log.error("update versioncounter failed")    
        else:
            if checkmount_alternate(True):
                alternate_versioncounter = current_versioncounter +1
                try:
                    with open(altversfilename(versioncounter_path), 'w') as f:
                        f.write(str(alternate_versioncounter))
                        log.info("alternate versioncounter updated")
                except:
                    log.error("update alternate versioncounter failed")
            else:
                log.error("write_versioncount: cannot update alternate versioncounter")


# called from gui.pyx
def configui_init(infstr):
    """
        init logging
        create GUI
        set callbacks
        initialise config
        initialise on-screen values
    """
    global configui
    global log
    global stable

    if stable:
        return

    log = logging.getLogger("zsipos.config")
    log.info ("configui_init...")
    log.info("gitdate: %x" %(gitdates["zsipos"], ))
    config_to_dict()
    ui = configui = new CONFIGUI()
    ui.window.position(0,60)
    ui.window.labeltype(FL_NORMAL_LABEL)
    ui.window.callback(on_config_close, NULL)
    # back button
    ui.btn_back.callback(on_btn_back, NULL)
    ui.btn_warn.callback(on_btn_warn, NULL)
    # tab_config - braucht genormte label
    ui.group_ip.label(str_ip_config)
    ui.group_server.label(str_server)
    ui.group_logs.label(str_logs)
    ui.group_experts.label(str_experts)
    ui.group_rootpw.label(str_rootpw)
    ui.group_reset.label(str_reset)
    ui.group_sysinfo.label(str_sysinfo)
    ui.group_update.label(str_update)
    ui.tab_config.callback(on_tab_group, NULL)
    ui.btn_help.callback(on_btn_help, NULL)
    # this tab is shown first
    group_init(ui.group_ip)
    ui.tab_config.value(ui.group_ip)
    # startup warning from gui.pyx
    if infstr:
        warn(infstr)

    stable = True
    log.info("... finished")
# configui_init

#enforce root password change on first startup
if os.path.exists(pw_reset):
    root_pw_is_set = False
    configui_init("")
    configui.btn_address_cancel.hide()
    configui.btn_address_back.hide()
    on_btn_rootpw(NULL, <void*>"initrootpw")
    while True:
        Fl.check()
        if root_pw_is_set:
            log.info("new password set")
            os.remove(pw_reset)
            break
