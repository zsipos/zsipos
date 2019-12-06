#
# configui.pxi
#
# Author: Esther Bergter
#
# Version 0.4

import time
import errno
import logging
import os
import re
import socket
import spwd
from subprocess import CalledProcessError
import subprocess
import sys
from time import sleep

import crypt
from gitversions import gitversions,gitdates
from iputils import split_host_port
from utils import getGitMagic,gitFormat,tstr

cdef CONFIGUI* configui

cdef Fl_Text_Buffer* helpTextBuffer

cdef constopt   # consts-Option, die gerade bearbeitet wird

cdef str section = 'gmitm'
cdef str str_ip_config = 'Ip Config'
cdef str help_ip_config = """
Setup your network configuration.

You can obtain your IP Address including the DNS setting automatically from a DHCP server or specify it manually. 
In this case you can use either IPv4 or IPv6 address.

IPv4:

address: 123.45.67.89
mask: 255.255.255.0

IPv6:

address: 1abc:45.678::9a
mask: 64
"""

cdef str str_server = 'Server'
cdef str help_server = """
SIP Proxy:

The name / Address and port of your SIP proxy

ICE Storage:

The URL of your ICE helper

http://name:port

STUN Server:

name:port

TURN Server:

name:port;u=user;p=pw

NTP Server:   time server

name
"""

cdef str str_experts = 'Experts'
cdef str help_experts = """
These settings should only be changed if you are aware of what you are doing! For normal operation please use the defaults.

Local Proxy:

This is the IP address of the zsipos box shown to the local IP phone. There is no reason to change the standard setting of 192.168.231.78. You must set this address in the local telephone as SIP proxy address.

skip zrtp1:

If the external Phone Address is behind NAT, select 'skip zrtp1' in order to save time. Do NOT select this option, if your IP-Address is routable. Default is off.

gitversions:

Shows the short git commit hashes of the components, that is the software version.
"""

cdef str str_reset = 'Reset'
cdef str help_reset ="""
Power off/on always reboots.

Restart:

Restart the program.

Reboot:

Reboot the machine.

Device Shutdown:

If you want to remove the SSD card, first shut down the unit, then unplug the power cord. Now you can safely remove the card.

Delete Trust Information:

Trusted partners and hosts are saved and re-used on next connection. If you delete the list, trust must be re-established.

Factory Reset:

Delete trust information, reset zsipos.cfg, reset network configuration, reset root password, reboot the system.
"""
cdef str oldpw = ''
cdef str newpw = ''

cdef str str_gitversions = ''
cdef str str_save_and_reconfig = 'Save and Reconfigure'
cdef str str_save_and_restart = 'Save and Restart'

cdef sendfiles = []

""" Callbacks """

# from application main
cdef void on_config_enter(Fl_Widget* widget, void *data) with gil:
    global sendfiles

    #debug("on config enter")
    # working copy of config
    config_to_dict()
    clearsendfiles()
    # initial screen values
    init_addresspar_editvals()
    init_noneditvals()
    update_overview()
    configui.window.activate()
    configui.tab_config.value(configui.group_ip)
    configui.btn_back.take_focus()
    configui.window.show()


# Config main
cdef void on_btn_shutdown(Fl_Widget* widget, void *data) with gil:
    """ shutdown application """
    configui.window.hide()
    mainui.window.hide()
    log.info("shutdown")
    exit(0)

cdef void on_btn_back(Fl_Widget* widget, void *data) with gil:
    do_back()

cdef void on_btn_warn(Fl_Widget* widget, void *data) with gil:
    configui.btn_warn.hide()
    configui.tab_config.show()

cdef void on_btn_help(Fl_Widget* widget, void *data) with gil:
    ui = configui
    label = get_label(get_value(ui.tab_config))
    #debug(label)

    if str(label) == str_ip_config:
        helpTextBuffer.text(help_ip_config)
    elif str(label) == str_server:
        helpTextBuffer.text(help_server)
    elif str(label) == str_experts:
        helpTextBuffer.text(help_experts)
    elif str(label) == str_reset:
        helpTextBuffer.text(help_reset)
    configui.helpDisplay.copy_label("Help")
    configui.winHelp.show()

cdef void on_btn_help_back(Fl_Widget* widget, void *data) with gil:
    configui.winHelp.hide()

cdef void on_tab_group(Fl_Widget *widget, void *data) with gil:
    global sendfiles
    ui = configui

    label = get_label(get_value(ui.tab_config))
    #debug("on_tab_group %s" %(label, ))
    if str(label) == str_experts:
        clearsendfiles()
    if str(label) in [str_ip_config, str_server, str_experts, str_reset]:
        show_help = True
    else:
        show_help = False # keine Hilfe
    if show_help:
        ui.btn_help.show()
    else:
        ui.btn_help.hide()


# callback Config Groups
# IP
cdef void on_btn_dhcp(Fl_Widget* widget, void *data) with gil:

    if get_value(configui.btn_dhcp) == 0:   # kein dhcp
        cfdict[consts.EXTUSEDHCP] = False
        configui.group_static_ip.activate()
        configui.btn_static_dns.value(1)
        configui.btn_auto_dns.value(0)
        configui.group_btn_dns.deactivate()
        configui.group_dns.activate()
    else:                                    # dhcp
        cfdict[consts.EXTUSEDHCP] = True
        configui.group_static_ip.deactivate()
        configui.group_btn_dns.activate()
        #debug("on_btn_dhcp btn_dns_server")
        dnsserver = addresspar[consts.DNSSERVER]['editvals'][0]
        #debug(dnsserver)
        if len(dnsserver) > 0:
            configui.btn_static_dns.value(1)
            configui.btn_auto_dns.value(0)
            configui.group_dns.activate()
        else:
            configui.btn_auto_dns.value(1)
            configui.btn_static_dns.value(0)
            configui.group_dns.deactivate()

cdef void on_btn_dns(Fl_Widget* widget, void *data) with gil:

    if get_value(configui.btn_auto_dns) == 0:
        cfdict['AutoDns'] = False
        configui.group_dns.activate()
    else:
        cfdict['AutoDns'] = True
        configui.group_dns.deactivate()

cdef void on_btn_ping(Fl_Widget *widget, void *cfdata) with gil:
    myopt = <str>cfdata
    #debug("on_btn_ping: myopt %s" % (myopt, ))
    params = addresspar[myopt]

    if myopt in cfdict and len(cfdict[myopt]):
        if 'splitfunction' in params:
            splitfunction = params['splitfunction']
            splitparams = params['splitparams']
            if splitparams[0] == 'scheme':
                n = 1
            else:
                n = 0
            splitvalues = splitfunction(cfdict[myopt])
            if len(splitvalues) >= n + 1:
                val = splitvalues[n]
            else:
                val = ""
        else:
            val = cfdict[myopt]
    else:
            val = ""
    #debug("on_btn_ping: val %s" % (val, ))
    do_ping(val)

cdef void on_btn_sysinfo(Fl_Widget *widget, void *data) with gil:

    show_sysinfo(<str>data)


cdef void on_btn_ifconfig(Fl_Widget *widget, void *data) with gil:

    show_ifconfig()


# callback Config Groups
# Experts
cdef void on_btn_sshd(Fl_Widget* widget, void *data) with gil:
    #debug(os.uname())
    if get_value(configui.btn_sshd) == 0:
        if os.uname()[1] == 'esther-vm2':
            debug('sshd requested stop')
        else:
            os.system('/etc/init.d/sshd stop')
    else:
        if os.uname()[1] == 'esther-vm2':
            debug('sshd requested start')
        else:
            os.system('/etc/init.d/sshd start')

cdef void on_btn_show_git(Fl_Widget* widget, void *data) with gil:
    global configui
    global helpTextBuffer

    helpTextBuffer.text(str_gitversions)
    configui.helpDisplay.copy_label("gitversion")
    configui.winHelp.show()

cdef void on_btn_addfiles(Fl_Widget* widget, void *data) with gil:
    size = configui.browse_archive.size()
    for index in range(1, size+1):
        if configui.browse_archive.selected(index):
            file = configui.browse_archive.text(index)
            #if len(file) > 2: # exclude . and ..
            add_file(file)
            #configui.browse_archive.select(index,0)

cdef void on_btn_removefiles(Fl_Widget* widget, void *data) with gil:
    size = configui.browse_archive.size()
    for index in range(1, size+1):
        if configui.browse_archive.selected(index):
            file = configui.browse_archive.text(index)
            if len(file) > 2: # exclude . and ..
                remove_file(file)
            configui.browse_archive.select(index,0)

cdef void on_btn_show_selected(Fl_Widget* widget, void *data) with gil:
    size = configui.browse_archive.size()
    for index in range(1, size+1):
        filename = configui.browse_archive.text(index)
        relfile = os.path.join("archive", filename)
        if relfile in sendfiles: # exclude . and ..
            configui.browse_archive.select(index,1)
        else:
            configui.browse_archive.select(index,0)

cdef void on_btn_upload(Fl_Widget* widget, void *data) with gil:
    if len(sendfiles):
        if not config_valid(consts.UPLOADID):
            if (not config_valid(consts.UPLOADUSER) or
                not config_valid(consts.UPLOADSERVER) or
                not config_valid(consts.UPLOADPORT)): # () for line continuation
                warn('Upload information missing')
                return;
            else:
                on_btn_edit_address(NULL, <void*>consts.UPLOADID)
                info('Please press send button again.')
                return;
        add_stdfiles()
        make_Manifest()
        do_send()
    else:
        warn('no files selected')

# callback Config Groups
# Passwd
cdef void on_btn_root_pw(Fl_Widget* widget, void *data) with gil:
    clearpw()
    on_btn_edit_address(NULL, <void*>"rootpw")

# callback Config Groups
# Reset
cdef void on_btn_restart(Fl_Widget* widget, void *data) with gil:
    restart_type = <str>data
    #debug(restart_type) 
    if config_has_changed():
        #debug("on_btn_restart found config_has_changed")
        do_back()
    else:
        do_restart(restart_type)

cdef void on_btn_fac_reset(Fl_Widget* widget, void *data) with gil:
    #debug("btn_fac_reset")
    if os.uname()[1] == 'esther-vm2':
        debug('factory reset requested')
    else:
        #debug('factory reset')
        for file in (consts.CFGFILE, consts.ZIDFILE, consts.NDBFILE):
            if os.path.isfile(file):
                log.info("remove "+file)
                os.remove(file)
        log.info("factory reset, reboot system")
        os.system('reboot')

cdef void on_btn_zid_reset(Fl_Widget* widget, void *data) with gil:
    for file in (consts.ZIDFILE, consts.NDBFILE):
        if os.path.isfile(file):
            log.info("remove "+file)
            os.remove(file)

cdef void on_btn_nxcal(Fl_Widget* widget, void *data) with gil:
    configui.window.hide()
    os.unlink('/etc/pointercal')
    os.system('export TSLIB_TSDEVICE=/dev/input/event0;/usr/bin/ts_calibrate')
    configui.window.show()

# SaveWindow
cdef void on_btn_save_and_restart(Fl_Widget* widget, void *data) with gil:

    do_save_cfg()
    configui.winSave.hide()
    configui.window.hide()
    do_restart(get_label(configui.btn_save_and_restart))


cdef void on_btn_save(Fl_Widget* widget, void *data) with gil:
    #debug("on_btn_save")
    do_save_cfg()
    configui.winSave.hide()
    configui.window.hide()


cdef void on_btn_cancel(Fl_Widget* widget, void *data) with gil:

    configui.winSave.hide()
    configui.window.hide()


# callbacks EditWindow
cdef void on_btn_edit_address(Fl_Widget* widget, void *cfdata) with gil:
    """ build initial EditWindow """ 
    global constopt
    global addresspar
    global key_state

    constopt = <str>cfdata
    params = addresspar[constopt]
    params['estep'] = 0

    read_val(params)
    init_cache(params)
    write_editwindow(params)
    select_button(params)

    # choose keyboard
    keyboard = params['keyboard']
    key_state = keyboard[0]
    keyboard_show(key_state)

    # warning off
    configui.btn_address_warn.hide()

    configui.winEditAddress.show()
# on_btn_edit_address

cdef void on_btn_address_back(Fl_Widget* widget, void *data) with gil:
    """show previous window"""
    global constopt

    #debug('on_btn_address_back')

    params = addresspar[constopt]
    estep = params['estep']
    #debug(estep)
    if estep > 0:
        estep -= 1
        params['estep'] = estep
        read_val(params)
        write_editwindow(params)
        select_button(params)
        keyboard = params['keyboard']
        key_state = keyboard[estep]
        keyboard_show(key_state)
        configui.btn_address_warn.hide()
        configui.winEditAddress.redraw()

    else: # back to config
        configui.tab_config.take_focus()
        configui.winEditAddress.hide()

# on_btn_address_back

cdef void on_btn_address_ok(Fl_Widget* widget, void *data) with gil:
    """ last window, save """
    global constopt

    params = addresspar[constopt]

    if address_cache(params):
        address_save(params)
        #debug("on_btn_address_ok editvals:")
        #debug(params['editvals'])
        configui.tab_config.redraw()
        configui.tab_config.take_focus()
        configui.winEditAddress.hide()
    else:
        show_warning(params)
# on_btn_address_ok

cdef void on_btn_address_next(Fl_Widget* widget, void *data) with gil:
    """ save value and show next window """
    global constopt # this option is to be saved next
    global key_state
    #debug('on_btn_address_next')
    #debug(constopt)
    params = addresspar[constopt]
    estep = params['estep']

    if address_cache(params):
        #debug("address_cache ok")
        estep += 1
        params['estep'] = estep
        #??read_val(params)
        write_editwindow(params)
        select_button(params)
        keyboard = params['keyboard']
        key_state = keyboard[estep]
        keyboard_show(key_state)
        configui.btn_address_warn.hide()
        configui.winEditAddress.redraw()

    else:
        show_warning(params)
# on_btn_address_next    

cdef void on_btn_address_cancel(Fl_Widget* widget, void *data) with gil:
    configui.tab_config.take_focus()
    configui.winEditAddress.hide()

cdef void on_btn_address_warn(Fl_Widget* widget, void *data) with gil:
    configui.btn_address_warn.hide()


# Keyboard
cdef void on_key(Fl_Widget* widget, void *cfdata) with gil:
    global key_state
    val = <str>cfdata

    configui.btn_address_warn.hide()
    configui.input_text.insert(val, 0)
    if key_state == 'ABC':
        key_state = 'abc'
        keyboard_show(key_state)
    configui.input_text.take_focus()

cdef void on_del(Fl_Widget* widget, void *data) with gil:
    configui.btn_address_warn.hide()
    configui.input_text.cut(-1)
    configui.input_text.take_focus()


cdef void on_back(Fl_Widget* widget, void *cfdata) with gil:
    i = <Fl_Input_*>cfdata
    configui.btn_address_warn.hide()
    pos = get_position(i)
    configui.input_text.position(pos-1, pos-1)
    configui.input_text.take_focus()

cdef void on_forward(Fl_Widget* widget, void *cfdata) with gil:
    i = <Fl_Input_*>cfdata
    pos = get_position(i)
    configui.input_text.position(pos+1, pos+1)
    configui.input_text.take_focus()

cdef void on_change_keyboard(Fl_Widget* widget, void *cfdata) with gil:
    val = <str>cfdata
    global key_state
    #debug(val)

    if val == 'abc':
        key_state = 'abc'
    elif val == '123':
        key_state = '123'
    elif val == 'shift':
        if key_state == 'abc':
            key_state = 'ABC'
        elif key_state == 'ABC':
            key_state = 'FixedABC'
        else: # Fixed
            key_state = 'abc'
    keyboard_show(key_state)
    configui.winEditAddress.redraw()

'''
# Python
'''
editcache = []

# Python Functions (alphabetical)
def add_file(char *filename):
    global sendfiles;

    relfile = os.path.join("archive", filename)
    if os.path.isfile(relfile):
        if relfile not in sendfiles:
            sendfiles.append(relfile)

def add_stdfiles():
    global sendfiles;
    stdfiles = ['nohup.out', 'Manifest']
    for relfile in stdfiles:
        if os.path.isfile(relfile):
            sendfiles.append(relfile)

def address_cache(params):
    """ save editvals to cache """
    global cfdict

    estep = params['estep']
    testfunctions = params['testfunctions']
    warnings = params['warnings']

    ei = estep # editval index

    if 'splitfunction' in params:
        splitparams = params['splitparams']
        if splitparams[0] == 'scheme':
            if estep == 0:
                if get_value(configui.btn_https) == 0:
                    editcache[0] = 'http'
                else:
                    editcache[0] = 'https'
            ei += 1

    editcache[ei] = get_value(configui.input_text)
    #debug('editcache[ei] ' + editcache[ei])
    if testfunctions[estep] is not None and len(editcache[ei]) > 0:
        debug_editcache("test für %s" %(editcache[ei], ))
        if not testfunctions[estep](editcache[ei]):
            configui.btn_address_warn.copy_label(warnings[estep])
            configui.btn_address_warn.show()
            configui.input_text.take_focus()
            return False
    debug_editcache("address_cache editcache:")
    debug_editcache(editcache)
    return True
# address_cache

def address_save(params):
    """ save editvals to cfdict """
    global cfdict
    global addresspar

    #debug("address_save %s" % (params['title']))
    estep = params['estep']
    options  = params['options']
    testfunctions = params['testfunctions']
    warnings = params['warnings']
    params['editvals']= list(editcache) # update editvals
    editvals = params['editvals']
    update   = params['update'] if 'update' in params else None
    debug_editcache("address_save editcache, editvals")
    debug_editcache(editcache)
    debug_editcache(editvals)

    if 'splitfunction' in params:
        splitparams = params['splitparams']
        concatfunc = params['concatfunction']
        clen = len(splitparams)
        #debug("splitparams %s, clen %d" %(splitparams, clen))
    else:
        clen = 1

    for estep in xrange(0, params['steps']):
        #debug("estep %d" % (estep, ))
        #debug("options: " + str(options))
        if options[estep] is not None:
            #skip passwords
            if options[estep] in ['oldpw', 'newpw', 'newpw2']:
                continue
            if clen == 1:             # simple case, just store it
                #debug("address_save: %s=%s" % (options[estep], editvals[estep]))
                cfdict[options[estep]] = editvals[estep]
            else:
                if clen == 2:
                    concatval = concatfunc(editvals[estep], editvals[estep+1])
                elif clen == 3:
                    concatval = concatfunc(editvals[estep], editvals[estep+1], editvals[estep+2])
                #debug("concatval %s" %(concatval, ))
                #debug(options[estep])
                cfdict[options[estep]] = concatval
                clen = 1 # do not concat additonal pars
    if update:
        for u in update:
            read_all_vals(addresspar[u])
    update_overview() # refresh overview
    return True
# address_save

def check_mandatories():
    if cfdict[consts.EXTUSEDHCP]:
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
    return ret

def check_mandatory_static_ip():
    ret = check_mandatory_value(consts.EXTPHONEADDR)
    ret += check_mandatory_value(consts.EXTPHONEPORT)
    ret += check_mandatory_value(consts.EXTNETMASK)
    ret += check_mandatory_value(consts.EXTGATEWAY)
    return ret

def check_mandatory_value(myopt):
    if myopt in cfdict and len(cfdict[myopt]) > 0:
        return ""
    else:
        params = addresspar[myopt]
        return "%s missing. " % (params['title'], )

def cfg_cleanup():
    if cfdict[consts.EXTUSEDHCP]:
        cfdict[consts.EXTPHONEADDR] = ""
        cfdict[consts.EXTNETMASK] = ""
        cfdict[consts.EXTGATEWAY] = ""
        if 'AutoDns' in cfdict and cfdict['AutoDns']:
            cfdict[consts.DNSSERVER] = ""
        #cfdict[consts.EXTUSEDHCP] = str(cfdict[consts.EXTUSEDHCP])
    if consts.EXTPROXYADDR in cfdict:
        del cfdict[consts.EXTPROXYADDR]
        config.remove_option(consts.SECTION, consts.EXTPROXYADDR) 
    if consts.EXTPROXYPORT in cfdict:
        del cfdict[consts.EXTPROXYPORT]
        config.remove_option(consts.SECTION, consts.EXTPROXYPORT)

def clearpw():
    oldpw = ""
    newpw = ""
    newpw2 = ""

def clearsendfiles():
    global sendfiles

    sendfiles = []
    size = configui.browse_archive.size()
    for index in range(1, size+1):
        configui.browse_archive.select(index,0)

def comparepw(pw):
    """ compare and save password"""
    global newpw

    #debug(newpw)
    #debug(pw)
    if newpw == pw:
        try:
            (ret,errstr) = save_root_pw(newpw)
        except:
            info = sys.exc_info()
            log.error("EXCEPTION: %s", info[1], exc_info=info)
            log.error("change password failed")
            return False
        if ret == 0:
            return True
        else:
            addresspar['rootpw']['warnings'][2] = errstr
            return False
    else:
        addresspar['rootpw']['warnings'][2] = 'Passwords do not match'
        return False

def concat_host_port(host, port):
    concat = host
    if len(host) and len(port):
        if is_valid_hostname(host) or is_valid_ipv4_address(host):
            concat = "%s:%s" %(host, port)
        elif is_valid_ipv6_address(host):
            concat = "[%s]:%s" % (host, port)

    return concat
# concat_host_port

def concat_url(scheme, ip, port):
    #debug("scheme %s, ip %s, port %s" % (scheme, ip, port))
    if is_valid_hostname(ip) or is_valid_ipv4_address(ip):
        concat = "%s://%s:%s" %(scheme, ip, port)
    elif is_valid_ipv6_address(ip):
        concat = "%s://[%s]:%s" % (scheme, ip, port)
    else:
        log.error("concat_url failed")
        concat = None
    return concat
# concat_url

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

    cfdict = dict(olddict) # make a copy

    # AutoDns
    if consts.EXTUSEDHCP in cfdict and cfdict[consts.EXTUSEDHCP]:
        if consts.DNSSERVER in cfdict and len(cfdict[consts.DNSSERVER]):
            cfdict['AutoDns'] = False
            olddict['AutoDns'] = False
        else:
            cfdict['AutoDns'] = True
            olddict['AutoDns'] = True

    #debug_dict("config_to_dict")
# config_to_dict

def config_valid(name):
    """ True if cfdict[name] is defined """
    return True if name in cfdict and cfdict[name] else False

def debug(string):
    return
    log.info(string)


def debug_dict(string, mydict=None):
    return
    debug(string)
    if mydict is None:
        mydict = cfdict
    for key in sorted(mydict.iterkeys()):
        s = '{}: {}'.format(key, mydict[key])
        debug(s)
    debug("end of cfdict..............................")

def debug_editcache(string):
    return
    debug(string)


def dict_to_config():
    """ copy dict items back to config. """

    #debug_dict("dict_to_config")
    for key, value in cfdict.items():
        if key == 'AutoDns':
            continue
        #debug("dict_to_config: %s=%s" %(key, str(value)))
        config.set(consts.SECTION, key, str(value))

def do_back():
    debug("do_back")
    #global configfile - wird nicht veraendert
    set_noneditvals()
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
        if res is None:
            inf = "config has changed"
            log.info(inf)
            configui.box_restart.copy_label(inf)
            configui.btn_save_and_restart.hide()
        else:
            inf = "config has changed, need %s" % (res, )
            log.info(inf)
            configui.box_restart.copy_label(inf)
            configui.btn_save_and_restart.copy_label(res)
            configui.btn_save_and_restart.show()
        configui.winSave.show()
    else:
        configui.window.hide()

'''
def do_back_fl_choice():
    debug("do_back")
    #global configfile - wird nicht veraendert
    set_noneditvals()
    missings = check_mandatories()
    #debug("check_mandatories: %s" % (missings, ))
    if len(missings):
        #debug("show warning")
        warn(missings)
        return
    if config_has_changed():
        #debug("config has changed")
        configui.window.hide()
        cfg_cleanup()
        res = need_restart()
        if res is None:
            inf = "config has changed"
            log.info(inf)
            choice = get_choice(inf, None)
        else:
            inf = "config has changed, need %s" % (res, )
            log.info(inf)
            choice = get_choice(inf, res)
        if choice > 0:
            do_save_cfg()
        if choice > 1:
            do_restart(res)

    else:
        configui.window.hide()
'''

def do_ping(host):
    global helpTextBuffer

    #debug("do_ping: host %s" % (host,))
    configui.helpDisplay.copy_label("ping")
    out = "ping %s ...\n" % (host,)
    helpTextBuffer.text(out)
    configui.winHelp.show()

    try:
        out += subprocess.check_output(["ping", "-c", "2", host], stderr=subprocess.STDOUT, encoding="utf8")
    except CalledProcessError as e:
        if len(e.output):
            out += e.output
        else:
            out += str(sys.exc_info()[1])
    finally:
        helpTextBuffer.text(out)


def do_restart(restart_type):
    """ restart application """
    if os.uname()[1] == 'esther-vm2':
        debug("%s requested" % (restart_type,))
    else:
        console.clear()
        if restart_type == 'reboot':
            console.info("reboot...")
            log.info("reboot system")
            os.system('reboot')
        elif restart_type == str_save_and_reconfig:
            console.info("reconfigure...")
            log.info("reconfig system")
            #os.system('/etc/init.d/rcK && /etc/init.d/rcS')
            os.system('reboot')
        elif restart_type == 'shutdown':
            console.info("shutdown...")
            log.info("shutdown system")
            os.system('poweroff')
        else:
            console.info("restart...")
            log.info("restart zsipos")
        os._exit(0)

def do_save_cfg():
    dict_to_config()
    if os.path.isfile(consts.CFGFILEBAK):
        os.unlink(consts.CFGFILEBAK)
    if os.path.isfile(consts.CFGFILE):
        os.rename(consts.CFGFILE, consts.CFGFILEBAK)
    with open(consts.CFGFILE, 'wb') as cfgfile:
        config.write(cfgfile)
        log.info("cfgfile saved")
        os.system('sync')

def do_send():
    myfiles = ' '.join(sendfiles)
    #debug('do_send')
    #debug(myfiles)
    cpcmd = "tar -cf - %s |  /usr/bin/ssh -T %s@%s -p %s" % (
            myfiles, cfdict[consts.UPLOADUSER], cfdict[consts.UPLOADSERVER], str(cfdict[consts.UPLOADPORT]))
    log.info(cpcmd)
    configui.helpDisplay.copy_label("upload")
    out = "uploading files\n  %s\n" % ('\n  '.join(sendfiles))
    helpTextBuffer.text(out)
    configui.winHelp.show() # visible only when finished

    try:
        retcode = subprocess.call(cpcmd, shell=True, encoding="utf8")
    except CalledProcessError as e:
        if len(e.output):
            out += e.output
        else:
            out += str(sys.exc_info()[1])
    finally:
        if (retcode == 0):
            out += 'successfully sent'
            clearsendfiles()
        helpTextBuffer.text(out)


'''
def get_choice(txt, restext):
    configui.winSave.show()
    if restext is None:
        choice = fl_choice3(txt, 'cancel', 'save', NULL)
        ret = choice
    else:
        choice = fl_choice3(txt, 'cancel', restext, 'save')
        if choice == 0:
            ret = choice
        elif choice == 1:
            ret = 2
        else:
            ret = 1
    configui.winSave.hide()
    return ret
'''

def gitversions_init():
    ''' read gitversions into str '''
    global str_gitversions

    str_gitversions = '\n'.join(gitFormat(i) for i in gitversions)
    #debug(str_gitversions)

def gitout_init():
    ''' read gitMagic, FPGA, KERNEL-GIT '''
    str_gitout = ("GIT-MAGIC: 0x%x\nFPGA-GIT: 0x%x\nKERNEL-GIT: 0x%x"
                   % (getGitMagic(), gitversions['FPGA-GIT'],
                      gitversions['KERNEL-GIT']))
    #gitoutTextBuffer = new Fl_Text_Buffer()
    #configui.gitoutDisplay.buffer(gitoutTextBuffer)
    configui.out_git_magic.value(str_gitout)

def info(infomessage):
    configui.btn_warn.copy_label(infomessage)
    configui.btn_warn.labelcolor(39)
    configui.tab_config.hide()
    configui.btn_warn.show()

def init_addresspar_editvals():
    ''' Initialise editvals in addresspar '''
    #debug("init_addresspar_editvals")
    for key in addresspar:
        #debug(key)
        read_all_vals(addresspar[key])
    #debug(addresspar)

def init_cache(params):
    """cache editvals"""
    global editcache

    debug_editcache('init_cache:')
    editcache = list(params['editvals'])
    debug_editcache(editcache)

def init_noneditvals():
    ui = configui
    #debug("init_noneditvals")
    # experts
    ui.btn_skipzrtp1.value(cfdict[consts.SKIPZRTP1])
    # log
    ui.log_external.value(cfdict[consts.LOGEXT])
    ui.log_local.value(cfdict[consts.LOGLOC])
    ui.log_full.value(cfdict[consts.LOGFULLMESSAGE])
    ui.log_cc_events.value(cfdict[consts.LOGCCEVENTS])
    ui.log_cc_messages.value(cfdict[consts.LOGCCMESSAGES])
    ui.log_bm_events.value(cfdict[consts.LOGBMEVENTS])
    ui.log_timers.value(cfdict[consts.LOGTIMERS])
    ui.log_sip_proctime.value(cfdict[consts.LOGSIPTIMING])
    ui.log_sip_debug_delay.value(cfdict[consts.SIPDELAY])
    ui.log_zrtp_events.value(cfdict[consts.LOGZRTPCB])
    ui.log_zsession_events.value(cfdict[consts.LOGZSESSIONCB])
    ui.log_ice.value(cfdict[consts.LOGICE])
    ui.log_dtmf.value(cfdict[consts.LOGDTMF])
    ui.log_level.value(float(cfdict[consts.PJLOGLEVEL]))


def is_last_step(params):
    estep = params['estep']
    steps = params['steps']
    if estep+1 < steps:
        return False
    else:
        return True

def is_url(params):
    ''' return true if an url '''
    #debug('is_url' + str(params))
    if 'splitparams'in params and params['splitparams'][0] == 'scheme':
        #debug('is_url' + str(params['splitparams']))
        return True
    else:
        return False

def is_valid_host(name):
    return is_valid_ip(name) or is_valid_hostname(name)


def is_valid_hostname(hostname):
    if len(hostname) > 255:
        return False
    if hostname[-1] == ".":
        hostname = hostname[:-1] # strip exactly one dot from the right, if present
    allowed = re.compile("(?!-)[A-Z\d-]{1,63}(?<!-)$", re.IGNORECASE)
    return all(allowed.match(x) for x in hostname.split("."))

def is_valid_ip(ip):
    """ Validate IP addresses. """
    return is_valid_ipv4_address(ip) or is_valid_ipv6_address(ip)

def is_valid_mask(mask):
    """ Validate netmask. """
    return is_valid_ipv4_mask(mask) or is_valid_ipv6_mask(mask)

def is_valid_ipv4_address(address):
    try:
        socket.inet_pton(socket.AF_INET, address)
    except AttributeError:  # no inet_pton here, sorry
        try:
            socket.inet_aton(address)
        except socket.error:
            return False
        return address.count('.') == 3
    except socket.error:  # not a valid address
        return False

    return True
# is_valid_ipv4_address

def is_valid_ipv4_mask(netmask):
    if netmask.count('.') == 3:
        try:
            socket.inet_aton(netmask) # valid numbers 
        except socket.error:
            return False
        s4 = netmask.split('.')
        c4 = list(map(int, s4))
        m = ((c4[0]*256+c4[1])*256+c4[2])*256+c4[3]
        #debug('subnet mask')
        #debug(bin(m))
        if m == 0:
            return False
        y = ~m + 2**32 # subnet has 32 bits
        #debug(bin(y))
        z = y +1
        #debug(bin(z))
        if (z & y):
            return False
        else:
            return True
    else:
        try:
            nt = int(netmask)
        except:
            return False
        if  nt > 0 and nt <= 32:
            return True
        else:
            return False

# is_valid_ipv4_address
def is_valid_ipv6_address(address):
    try:
        socket.inet_pton(socket.AF_INET6, address)
    except socket.error:  # not a valid address
        return False
    return True

def is_valid_ipv6_mask(netmask):
    try:
        nt = int(netmask)
    except:
        return False
    if  nt >= 8 and nt <= 128:
        return True
    else:
        return False

def is_valid_port(testport):

    try:
        port = int(testport)
    except:
        #debug("is_valid_port got %s" %(testport,))
        return False
    #debug("port=%d" %(port,))
    if port > 0 and port < 65536:
        return True
    else:
        return False
# is_valid_port

def keyboard_init():
    global configui

    # keyboardgroup_func 
    configui.key_del.callback(on_del, NULL)
    configui.key_back.callback(on_back, configui.input_text)
    configui.key_forward.callback(on_forward, configui.input_text)
    configui.key_123.callback(on_change_keyboard, <void*>'123')
    configui.key_abc.callback(on_change_keyboard, <void*>'abc')
    configui.key_shift.callback(on_change_keyboard, <void*>'shift')

    # keyboardgroup_alpha_lower
    configui.key_a.callback(on_key, <void *>"a")
    configui.key_b.callback(on_key, <void *>"b")
    configui.key_c.callback(on_key, <void *>"c")
    configui.key_d.callback(on_key, <void *>"d")
    configui.key_e.callback(on_key, <void *>"e")
    configui.key_f.callback(on_key, <void *>"f")
    configui.key_g.callback(on_key, <void *>"g")
    configui.key_h.callback(on_key, <void *>"h")
    configui.key_i.callback(on_key, <void *>"i")
    configui.key_j.callback(on_key, <void *>"j")
    configui.key_k.callback(on_key, <void *>"k")
    configui.key_l.callback(on_key, <void *>"l")
    configui.key_m.callback(on_key, <void *>"m")
    configui.key_n.callback(on_key, <void *>"n")
    configui.key_o.callback(on_key, <void *>"o")
    configui.key_p.callback(on_key, <void *>"p")
    configui.key_q.callback(on_key, <void *>"q")
    configui.key_r.callback(on_key, <void *>"r")
    configui.key_s.callback(on_key, <void *>"s")
    configui.key_t.callback(on_key, <void *>"t")
    configui.key_u.callback(on_key, <void *>"u")
    configui.key_v.callback(on_key, <void *>"v")
    configui.key_w.callback(on_key, <void *>"w")
    configui.key_x.callback(on_key, <void *>"x")
    configui.key_y.callback(on_key, <void *>"y")
    configui.key_z.callback(on_key, <void *>"z")

    # keyboardgroup_alpha_upper
    configui.key_A.callback(on_key, <void *>"A")
    configui.key_B.callback(on_key, <void *>"B")
    configui.key_C.callback(on_key, <void *>"C")
    configui.key_D.callback(on_key, <void *>"D")
    configui.key_E.callback(on_key, <void *>"E")
    configui.key_F.callback(on_key, <void *>"F")
    configui.key_G.callback(on_key, <void *>"G")
    configui.key_H.callback(on_key, <void *>"H")
    configui.key_I.callback(on_key, <void *>"I")
    configui.key_J.callback(on_key, <void *>"J")
    configui.key_K.callback(on_key, <void *>"K")
    configui.key_L.callback(on_key, <void *>"L")
    configui.key_M.callback(on_key, <void *>"M")
    configui.key_N.callback(on_key, <void *>"N")
    configui.key_O.callback(on_key, <void *>"O")
    configui.key_P.callback(on_key, <void *>"P")
    configui.key_Q.callback(on_key, <void *>"Q")
    configui.key_R.callback(on_key, <void *>"R")
    configui.key_S.callback(on_key, <void *>"S")
    configui.key_T.callback(on_key, <void *>"T")
    configui.key_U.callback(on_key, <void *>"U")
    configui.key_V.callback(on_key, <void *>"V")
    configui.key_W.callback(on_key, <void *>"W")
    configui.key_X.callback(on_key, <void *>"X")
    configui.key_Y.callback(on_key, <void *>"Y")
    configui.key_Z.callback(on_key, <void *>"Z")
    configui.key_dot_alpha.callback(on_key, <void *>".")
    configui.key_comma_alpha.callback(on_key, <void *>",")

    # keyboardgroup_num
    configui.key_1.callback(on_key, <void *>"1")
    configui.key_2.callback(on_key, <void *>"2")
    configui.key_3.callback(on_key, <void *>"3")
    configui.key_4.callback(on_key, <void *>"4")
    configui.key_5.callback(on_key, <void *>"5")
    configui.key_6.callback(on_key, <void *>"6")
    configui.key_7.callback(on_key, <void *>"7")
    configui.key_8.callback(on_key, <void *>"8")
    configui.key_9.callback(on_key, <void *>"9")
    configui.key_0.callback(on_key, <void *>"0")
    configui.key_at.callback(on_key, <void *>"@")
    configui.key_colon.callback(on_key, <void *>":")
    configui.key_semicolon.callback(on_key, <void *>";")
    configui.key_underscore.callback(on_key, <void *>"_")
    configui.key_minus.callback(on_key, <void *>"-")
    configui.key_hash.callback(on_key, <void *>"#")
    configui.key_colon.callback(on_key, <void *>":")
    configui.key_lparenthesis.callback(on_key, <void *>"(")
    configui.key_rparenthesis.callback(on_key, <void *>")")
    configui.key_slash.callback(on_key, <void *>"/")
    configui.key_plus.callback(on_key, <void *>"+")
    configui.key_dot_num.callback(on_key, <void *>".")
    configui.key_comma_num.callback(on_key, <void *>",")
    configui.key_question.callback(on_key, <void *>"?")
    configui.key_exclamation.callback(on_key, <void *>"!")
    configui.key_singlequote.callback(on_key, <void *>"'")
    configui.key_doublequote.callback(on_key, <void *>'"')

# keyboard_init

def keyboard_show(key_state):

    #debug(key_state)
    if key_state == '123':
        configui.keyboardgroup_alpha.hide()
        configui.key_123.hide()
        configui.key_shift.hide()
        configui.keyboardgroup_num.show()
        configui.key_abc.show()

    elif key_state == 'abc':
        configui.key_shift.color(49)
        configui.keyboardgroup_num.hide()
        configui.keyboardgroup_alpha_upper.hide()
        configui.key_abc.hide()
        configui.keyboardgroup_alpha.show()
        configui.keyboardgroup_alpha_lower.show()
        configui.key_123.show()
        configui.key_shift.show()
    elif key_state == 'ABC':
        # was 'abc'
        configui.keyboardgroup_alpha_lower.hide()
        configui.keyboardgroup_alpha_upper.show()
    elif key_state == 'FixedABC':
        # was 'ABC'
        configui.key_shift.color(39)

#keyboard_show

def make_Manifest():
    mversion = '0.1'
    file = open('Manifest', 'w')
    file.write('Manifest Version %s\n' % (mversion))
    file.write('    Customer:  %s\n' % (cfdict[consts.UPLOADID], ))
    file.write('    Timestamp: %s\n' % (tstr(int(time.time()))))
    file.write('\nVersions:\n')
    file.write("    GIT-MAGIC: %s\n" % (hex(getGitMagic())))
    for i in sorted(gitversions):
        file.write("    %s\n" % (gitFormat(i), ))
    file.write('\nFiles:\n')
    for fn in sorted(sendfiles):
        file.write('    %s\n' % (fn,))
    file.write('\nConfig:\n')
    for key, value in sorted(cfdict.items()):
        if key == 'AutoDns':
            continue
        if key == 'turnPassword':
            file.write("    %s=****" % (key,))
        else:
            file.write("    %s=%s" % (key, str(value)))
        file.write('\n')

def need_restart():
    """ scan options in addresspar, some extras"""
    # reconfig has priority
    # change from/to DHCP
    if consts.EXTUSEDHCP in olddict:
        if str(olddict[consts.EXTUSEDHCP]) != str(cfdict[consts.EXTUSEDHCP]):
            log.info(consts.EXTUSEDHCP + " changed")
            return str_save_and_reconfig
    elif consts.EXTUSEDHCP in cfdict and cfdict[consts.EXTUSEDHCP]:
        log.info(consts.EXTUSEDHCP + " activated")
        return str_save_and_reconfig
    # reconfig in addresspar
    for key in addresspar:
        param = addresspar[key]
        options = param['options']
        if 'restart_on_change' in param and param['restart_on_change'] == 'reconfig':
            for o in options:
                # Wenn DHCP gesetzt, ignoriere extPhoneAddr und extPhonePort
                if consts.EXTUSEDHCP in cfdict and cfdict[consts.EXTUSEDHCP]:
                    if o == consts.EXTPHONEADDR or o == consts.EXTPHONEPORT:
                        continue
                if o in cfdict and (o not in olddict or olddict[o] != cfdict[o]):
                    log.info('option %s=%s needs reconfig' % (o, cfdict[o]))
                    return str_save_and_reconfig
    # restart in addresspar
    for key in addresspar:
        param = addresspar[key]
        options = param['options']
        if 'restart_on_change' in param and param['restart_on_change'] == 'restart':
            for o in options:
                if o in cfdict and (o not in olddict or olddict[o] != cfdict[o]):
                    log.info('option %s=%s needs restart' % (o, cfdict[o] or ''))
                    return str_save_and_restart
    # Port changes
    if consts.EXTPHONEPORT in olddict:
        if olddict[consts.EXTPHONEPORT] != cfdict[consts.EXTPHONEPORT]:
            log.info(consts.EXTPHONEPORT + " changed")
            return str_save_and_restart
    elif consts.LOCPROXYPORT in olddict:
        if olddict[consts.LOCPROXYPORT] != cfdict[consts.LOCPROXYPORT]:
            log.info(consts.LOCPROXYPORT + " changed")
            return str_save_and_restart
    log.info("restart not needed")
    return None
# need_restart

def oldpwtest(testpw):
    try:
        oldorig = spwd.getspnam('root')
    except KeyError:
        info = sys.exc_info()
        addresspar['rootpw']['warnings'][0] = "%s\nare you root?" % (info[1], )
        return False
    #debug(testpw)
    if crypt.crypt(testpw, oldorig.sp_pwd) == oldorig.sp_pwd:
        #debug('oldpw ok')
        return True
    else:
        addresspar['rootpw']['warnings'][0] = 'Password is wrong.'
        return False

def read_all_vals(params):
    #debug(params['title'])
    for estep in xrange(0, params['steps']):
        params['estep'] = estep
        read_val(params)

def read_val(params):

    estep = params['estep']
    steps = params['steps']
    options = params['options']
    if 'splitfunction' in params:
        splitfunction = params['splitfunction']
        splitparams = params['splitparams']
    slen = len(options)
    if not 'editvals' in params:
        params['editvals'] = [None] * slen
        #debug("new editvals %d" % (slen,))
    editvals = params['editvals']
    # read existing value
    #debug('read_val %d options %s editvals %s' %(estep, options, editvals))
    if options[estep] is not None:
        if is_last_step(params) or options[estep +1] is not None:
            # option is editval
            #debug("option is editval")
            if options[estep] in cfdict:
                editvals[estep] = cfdict[options[estep]]
                #debug(editvals[estep])
            else:
                editvals[estep] = ''
        else:
            # option is concatenated [http://]ip:port 
            i = 0
            if options[estep] in cfdict:
                concatval = cfdict[options[estep]]
                #debug("concatval " + concatval)
                splitparams = splitfunction(concatval)
                #debug(splitparams)
                for val in splitparams:
                    editvals[estep+i] = val
                    i += 1
            else:
                for keys in splitparams:
                    editvals[estep+i] = ''
                    i += 1
            #debug(editvals)
# read_val            

def remove_file(char *filename):
    global sendfiles;

    relfile = os.path.join("archive", filename)
    if os.path.isfile(relfile):
        if relfile in sendfiles:
            sendfiles.remove(relfile)

def save_root_pw(newpw):

    cmd = ['/usr/bin/passwd', 'root']
    PIPE=subprocess.PIPE
    p = subprocess.Popen(cmd, stdin=PIPE, stderr=PIPE, stdout=PIPE, encoding="utf8")
    input = u'%(p)s\n%(p)s\n' % { 'p': newpw }
    (out,err) = p.communicate(input)
    if p.returncode == 0:
        out = out.strip()
        return (p.returncode, str(out))
    else:
        err = err.strip()
        return (p.returncode, str(err))

def select_button(params):
    """ set ok button or next button """
    estep = params['estep']
    steps = params['steps']

    if is_last_step(params):
        # just one window
        configui.btn_address_ok.show()
        configui.btn_address_next.hide()
    else:
        configui.btn_address_ok.hide()
        configui.btn_address_next.show()

# select_button

def set_noneditvals():
    global cfdict
    ui = configui
    
    # ip
    if is_visible(ui.btn_dhcp):
        cfdict[consts.EXTUSEDHCP] = to_bool(get_value(ui.btn_dhcp))
    # experts
    cfdict[consts.SKIPZRTP1] = to_bool(get_value(ui.btn_skipzrtp1))
    # log
    cfdict[consts.LOGEXT] = to_bool(get_value(ui.log_external))
    cfdict[consts.LOGLOC] =to_bool(get_value(ui.log_local))
    cfdict[consts.LOGFULLMESSAGE] =to_bool(get_value(ui.log_full))
    cfdict[consts.LOGCCEVENTS] =to_bool(get_value(ui.log_cc_events))
    cfdict[consts.LOGCCMESSAGES] =to_bool(get_value(ui.log_cc_messages))
    cfdict[consts.LOGBMEVENTS] =to_bool(get_value(ui.log_bm_events))
    cfdict[consts.LOGTIMERS] =to_bool(get_value(ui.log_timers))
    cfdict[consts.LOGSIPTIMING] =to_bool(get_value(ui.log_sip_proctime))
    cfdict[consts.SIPDELAY] =to_bool(get_value(ui.log_sip_debug_delay))
    cfdict[consts.LOGZRTPCB] =to_bool(get_value(ui.log_zrtp_events))
    cfdict[consts.LOGZSESSIONCB] =to_bool(get_value(ui.log_zsession_events))
    cfdict[consts.LOGICE] =to_bool(get_value(ui.log_ice))
    cfdict[consts.LOGDTMF] =to_bool(get_value(ui.log_dtmf))
    cfdict[consts.PJLOGLEVEL] =str(int(get_value(ui.log_level)))
#set_noneditvals

def show_sysinfo(filename):
    global helpTextBuffer

    try:
        out = subprocess.check_output(["tail", "-200", filename], stderr=subprocess.STDOUT, encoding="utf8")
    except CalledProcessError as e:
        if len(e.output):
            warn(e.output)
        else:
            warn(str(sys.exc_info()[1]))
        return
    helpTextBuffer.text(out)
    Display=configui.helpDisplay
    Display.copy_label(filename)
    lines = Display.count_lines(1, helpTextBuffer.length(), True)
    Display.scroll(lines, 0)
    configui.winHelp.show()

def show_ifconfig():
    global helpTextBuffer

    try:
        out = subprocess.check_output(["ifconfig", ], encoding="utf8")
    except CalledProcessError:
        pass
    helpTextBuffer.text(out)
    configui.helpDisplay.copy_label("ifconfig")
    configui.winHelp.show()

def show_upload(str1, str2, str3, str4):
    #debug("show_upload %s %s %s %s" %(str1,str2, str3, str4))
    if str1 is not None:
        ret = "%s%s%s:%s;id=%s" % (str3, ":", str1, str2, str4) # '@' terminates output
    else:
        ret = "  "
    #debug("show_upload ret=%s" %(ret))
    return ret

def show_turn(str1, str2, str3, str4):
    debug('show_turn')
    if str1 is not None:
        ip_port = concat_host_port(str1, str2) if concat_host_port(str1, str2) else ""
        return ("%s;u=%s;p=%s" % (ip_port, str3, str4))
    else:
        return "  "


def show_value(params):

    editvals = params['editvals']
    #debug("show_value %s:" %(params['title'], ))
    #debug("show_value editvals:")
    #debug(editvals)

    newval = editvals[0]

    if len(newval) > 0 and 'showfunction' in params:
        showfunction = params['showfunction']
        clen = len(editvals)
        newval = showfunction(*editvals)
    #debug('show_value newval <%s>' % (newval,))
    if newval is not None:
        return " " + newval
    else:
        return " "
# show_value

def show_warning(params):
    warnings = params['warnings']
    estep = params['estep']

    if warnings[estep] is not None:
        warn = warnings[estep]
    else:
        warn = 'Invalid Input'
    configui.btn_address_warn.copy_label(warn)
    configui.btn_address_warn.show()

'''
def split_host_port(input):
    #debug("split_host_port " + input)
    re_host = re.compile('((\w+[\.]?)+):(\d+)')
    re_v6 = re.compile('\[([^\]]*)\]:(\d+)')
    re_v4 = re.compile('(\d[^:]*):(\d+)')
    result = re_host.search(input)
    if not result:
        #debug(v6)
        result = re_v6.search(input)
        if not result:
            #debug(v4)
            result = re_v4.match(input)
    #debug(result)
    if result is not None:
        if result.lastindex >= 2:
            return result.group(1, result.lastindex)
        elif result.lastindex == 1:
            return (result.gropu(1), "")
    debug("split_host_port failed: " + input)
    return ("","")
# split_host_port
'''
def split_url(input):
    #debug("split_url " + input)
    re_host = re.compile('(http[s]?)://((\w+[\.]?)+):(\d+)')
    re_v6 = re.compile('(http[s]?)://\[([^\]]*)\]:(\d+)')
    re_v4 = re.compile('(http[s]?)://(\d[^:]*):(\d+)')
    result = re_host.search(input)
    if not result:
        #debug(v6)
        result = re_v6.search(input)
        if not result:
            #debug(v4)
            result = re_v4.match(input)
    #debug(result)
    if result is not None:
        if result.lastindex > 2:
            return result.group(1, 2, result.lastindex)
    log.error("split_url failed: " + input)
    return ("","","")
# split_url

def storenewpw(pw):
    """ copy input to newpw """
    global newpw
    newpw = pw
    return True

def to_bool(myint):
    if myint is None:
        return False
    try:
        i = int(myint)
    except:
        return True
    if i == 0:
        return False
    else:
        return True

def update_overview():
    ''' Fills in the overview fields '''
    global configui
    ui = configui
    #debug_dict("update_overview")

    if consts.EXTUSEDHCP in cfdict and cfdict[consts.EXTUSEDHCP]:
        #debug('set btn_dhcp, unset btn_static_ip')
        ui.btn_dhcp.value(1)
        ui.btn_static_ip.value(0)
        ui.group_btn_dns.activate()
        ui.group_static_ip.deactivate()
        dnsserver = addresspar[consts.DNSSERVER]['editvals'][0]
        if consts.DNSSERVER in cfdict and len(dnsserver):
            ui.group_dns.activate()
            ui.btn_static_dns.value(1)
            ui.btn_auto_dns.value(0)
        else:
            ui.btn_static_dns.value(0)
            ui.btn_auto_dns.value(1)
    else:
        #debug('set btn_static_ip')
        ui.btn_dhcp.value(0)
        ui.btn_static_ip.value(1)
        ui.btn_static_dns.value(1)
        ui.btn_auto_dns.value(0)
        ui.group_btn_dns.deactivate()
        ui.group_static_ip.activate()
        ui.group_dns.activate()

    params = addresspar[consts.EXTPHONEADDR]
    newval = show_value(params)
    ui.btn_ext_phone.copy_label(newval)
    ui.btn_ext_phone.value(" " + params['title'])
    #
    params = addresspar[consts.SIPPROXY]
    newval = show_value(params)
    ui.btn_sip_proxy.copy_label(newval)
    ui.btn_sip_proxy.value(" " + params['title'])
    #
    params = addresspar[consts.LOCPROXYADDR]
    newval = show_value(params)
    ui.btn_local_proxy.copy_label(newval)
    ui.btn_local_proxy.value(" " + params['title'])
    #
    params = addresspar[consts.ICESTORAGEURL]
    newval = show_value(params)
    ui.btn_ice_storage.copy_label(newval)
    ui.btn_ice_storage.value(" " + params['title'])
    #
    params = addresspar[consts.STUNSERVER]
    newval = show_value(params)
    ui.btn_stun_server.copy_label(newval)
    ui.btn_stun_server.value(" " + params['title'])
    #
    params = addresspar[consts.TURNSERVER]
    newval = show_value(params)
    ui.btn_turn_server.copy_label(newval)
    ui.btn_turn_server.value(" " + params['title'])
    #
    params = addresspar[consts.DNSSERVER]
    newval = show_value(params)
    ui.btn_dns_server.copy_label(newval)
    ui.btn_dns_server.value(" " + params['title'])
    #
    params = addresspar[consts.NTPSERVER]
    newval = show_value(params)
    ui.btn_ntp_server.copy_label(newval)
    ui.btn_ntp_server.value(" " + params['title'])
    #
    params = addresspar[consts.EXTGATEWAY]
    newval = show_value(params)
    ui.btn_gateway.copy_label(newval)
    ui.btn_gateway.value(" " + params['title'])
    #
    params = addresspar[consts.EXTNETMASK]
    newval = show_value(params)
    ui.btn_subnet_mask.copy_label(newval)
    ui.btn_subnet_mask.value(" " + params['title'])
    #
    params = addresspar[consts.UPLOADSERVER]
    newval = show_value(params)
    #debug('update_overview uploadserver: <%s>' % (newval))
    ui.btn_upload_server.copy_label(newval)
    ui.btn_upload_server.value(" " + params['title'])
    #

# update_overview

def warn(warnmessage):
    configui.btn_warn.copy_label(warnmessage)
    configui.btn_warn.labelcolor(88)
    configui.tab_config.hide()
    configui.btn_warn.show()

def write_editwindow(params):
    global editcache
    debug_editcache('write_editwindow editcache:')
    debug_editcache(editcache)

    lname = params['title']
    heads = params['heads']
    estep  = int(params['estep'])
    editvals = editcache
    if is_url(params):
        #debug('write_window is_url, estep %d' %(estep,))
        if estep == 0:
            #debug('show https')
            if editvals[estep] == 'http':
                configui.btn_https.value(0)
            else:
                configui.btn_https.value(1)
            configui.btn_https.show()
        else:
            #debug(estep)
            #debug('hide btn_https')
            configui.btn_https.hide()
        ei = estep + 1
    else:
        #debug('hide btn_https')
        configui.btn_https.hide()
        ei = estep

    configui.addressgroup.copy_label(lname)
    configui.input_text.copy_label(heads[estep])
    configui.input_text.value(editvals[ei])
 
''' 
defines for Edit Address
addresspar needs functions declared above
'''
stdheads = ["Full DNS name (FQDN) or IP Address", "Port"]
stdtests = [is_valid_host, is_valid_port]
stdwarnings = ["Not a valid Host", "Not a valid Port"]
stdsplitparams = ["FQDN or IP", "Port"]
stdkeyboard = ['abc', '123']
stdshowfunction = concat_host_port

addresspar = {
              consts.DNSSERVER: {
                'title': "DNS Server",
                'heads': ["IP Address"],
                'options': [consts.DNSSERVER],
                'keyboard': ['123'],
                'restart_on_change': 'reconfig',
                'testfunctions': [is_valid_ip],
                'warnings' : ["Not a valid IP Address"],
                'steps': 1 },
              consts.EXTPHONEADDR: {
                'title': "My IP Address",
                'heads': ["IP Address", "Port"],
                'options': [consts.EXTPHONEADDR, consts.EXTPHONEPORT],
                'keyboard': ['123', '123'],
                'restart_on_change': 'reconfig',
                'showfunction': stdshowfunction,
                'testfunctions': [is_valid_ip, is_valid_port],
                'warnings' : ["Not a valid IP Address", "Not a valid Port"],
                'mandatory' : True,
                'steps': 2 },
              consts.EXTGATEWAY: {
                'title': "Gateway", 
                'heads': ["IP Address"],
                'options': [consts.EXTGATEWAY],
                'keyboard': ['123'],
                'restart_on_change': 'reconfig',
                'testfunctions': [is_valid_ip],
                'warnings' : ["Not a valid IP Address"],
                'steps': 1 },
              consts.EXTNETMASK: {
                'title': "Subnet Mask", 
                'heads': ["IP Address", "Mask"],
                'options': [consts.EXTNETMASK],
                'keyboard': ['123'],
                'restart_on_change': 'reconfig',
                'testfunctions': [is_valid_mask],
                'warnings' : ["Not a valid Mask"],
                'steps': 1 },
              consts.SIPPROXY: {
                'title': "SIP Proxy",
                'heads': stdheads,
                'options': [consts.SIPPROXY, None],
                'concatfunction': concat_host_port,
                'keyboard': stdkeyboard,
                'restart_on_change': 'restart',
                'showfunction': stdshowfunction,
                'splitfunction': split_host_port,
                'splitparams': stdsplitparams,
                'testfunctions': stdtests,
                'warnings' : stdwarnings,
                'mandatory' : True,
                'steps': 2 },
              consts.ICESTORAGEURL: {
                'title': "ICE Storage URL",
                'heads': stdheads,
                'options': [consts.ICESTORAGEURL, None, None ],
                'concatfunction': concat_url,
                'keyboard': stdkeyboard,
                'restart_on_change': 'restart',
                'showfunction': concat_url,
                'splitfunction': split_url,
                'splitparams': ["scheme", ] + stdsplitparams,
                'testfunctions': stdtests,
                'warnings': stdwarnings,
                'mandatory' : True,
                'steps': 2 },
              consts.STUNSERVER: {
                'title': "STUN Server",
                'heads': stdheads,
                'options': [consts.STUNSERVER, None],
                'concatfunction': concat_host_port,
                'keyboard': stdkeyboard,
                'restart_on_change': 'restart',
                'showfunction': stdshowfunction,
                'splitfunction': split_host_port,
                'splitparams': stdsplitparams,
                'testfunctions': stdtests,
                'warnings' : stdwarnings,
                'steps': 2 },
              consts.TURNSERVER: {
                'title': "TURN Server",
                'heads': stdheads + ["User", "Password"],
                'options': [consts.TURNSERVER, None, consts.TURNUSER, consts.TURNPASSWORD],
                'concatfunction': concat_host_port,
                'keyboard': ['abc', '123', 'abc', 'abc'],
                'restart_on_change': 'restart',
                'showfunction': show_turn,
                'splitfunction': split_host_port,
                'splitparams': stdsplitparams,
                'testfunctions': stdtests + [None, None],
                'warnings' : stdwarnings + [None, None],
                'steps': 4 },
              consts.NTPSERVER: {
                'title': "NTP Server",
                'heads': ["IP Address"],
                'options': [consts.NTPSERVER],
                'keyboard': ['abc'],
                'restart_on_change': 'reconfig',
                'testfunctions': [is_valid_host],
                'warnings' : ["Not a valid Host Name"],
                'steps': 1 },
              consts.LOCPROXYADDR: {
                'title': "Local Proxy",
                'heads': stdheads,
                'options': [consts.LOCPROXYADDR, consts.LOCPROXYPORT],
                'keyboard': stdkeyboard,
                'restart_on_change': 'reconfig',
                'showfunction': stdshowfunction,
                'testfunctions': stdtests,
                'warnings' : stdwarnings,
                'mandatory' : True,
                'steps': 2 },
              consts.UPLOADSERVER: {
                'title': "Upload Server",
                'heads': stdheads + ["User", "UploadId"],
                'options': [consts.UPLOADSERVER, consts.UPLOADPORT, consts.UPLOADUSER, consts.UPLOADID],
                'keyboard': ['abc', '123', 'abc', 'abc'],
                'restart_on_change': None,
                'showfunction': show_upload,
                'testfunctions': stdtests + [None, None],
                'warnings' : stdwarnings + [None, None],
                'steps': 4 },
              consts.UPLOADID: {
                'title': "Upload Id",
                'heads': ["UploadId"],
                'options': [consts.UPLOADID],
                'keyboard': ['abc'],
                'restart_on_change': None,
                'showfunction': show_upload,
                'testfunctions':  [None],
                'warnings' : [None],
                'update' : [consts.UPLOADSERVER],
                'steps': 1 },
              'rootpw': {
                'title': "Change root password",
                'heads': ["old password", "new_password", "repeat new password"],
                'options': ['oldpw', 'newpw', 'newpw2'],
                'keyboard': ['abc', 'abc', 'abc'],
                'restart_on_change': None,
                'testfunctions': [oldpwtest, storenewpw, comparepw],
                'warnings': ['Password is wrong.', 'None', 'Passwords do not match.'],
                'steps': 3 }
             }

# needs all above

def configui_init(infstr):
    """ create GUI
        set callbacks
        initialise config
        initialise on-screen values
    """
    global configui
    global helpTextBuffer
    global stable

    log = logging.getLogger("zsipos.config")
    log.info ("configui_init...")
    log.info("gitdate: %x" %(gitdates["zsipos"], ))
    ui = configui = new CONFIGUI()
    ui.window.position(0,60)
    ui.window.labeltype(FL_NORMAL_LABEL)
    #ui.window.callback(on_config_enter, <void*>configui)
    #ui.window.callback(on_config_close, NULL)
    # back button
    ui.btn_back.callback(on_btn_back, NULL)
    ui.btn_warn.callback(on_btn_warn, NULL)
    # tab_config - braucht genormte label
    ui.group_ip.copy_label(str_ip_config)
    ui.group_server.copy_label(str_server)
    ui.group_experts.copy_label(str_experts)
    ui.tab_config.callback(on_tab_group, NULL)
    # help
    helpTextBuffer = new Fl_Text_Buffer()
    ui.helpDisplay.buffer(helpTextBuffer)
    ui.helpDisplay.wrap_mode(3, 0) # 3=WRAP_AT_BOUNDS
    ui.helpDisplay.scrollbar_width(20)
    helpTextBuffer.text(help_ip_config)

    ui.btn_help.callback(on_btn_help, NULL)
    ui.btn_help_back.callback(on_btn_help_back, NULL)

    # save window
    ui.btn_save_and_restart.callback(on_btn_save_and_restart, NULL)
    ui.btn_save.callback(on_btn_save, NULL)
    ui.btn_cancel.callback(on_btn_cancel, NULL)

    # ConfigItems
    # Group IP
    ui.btn_dhcp.callback(on_btn_dhcp, NULL)
    ui.btn_static_ip.callback(on_btn_dhcp, NULL)
    ui.btn_auto_dns.callback(on_btn_dns, NULL)
    ui.btn_static_dns.callback(on_btn_dns, NULL)
    ui.btn_ext_phone.callback(on_btn_edit_address, <void*>consts.EXTPHONEADDR)
    ui.btn_gateway.callback(on_btn_edit_address, <void*>consts.EXTGATEWAY)
    ui.btn_ping_gateway.callback(on_btn_ping, <void*>consts.EXTGATEWAY)
    ui.btn_subnet_mask.callback(on_btn_edit_address, <void*>consts.EXTNETMASK)
    ui.btn_dns_server.callback(on_btn_edit_address, <void*>consts.DNSSERVER)
    ui.btn_ping_dns.callback(on_btn_ping, <void*>consts.DNSSERVER)
    # Group Server
    ui.btn_sip_proxy.callback(on_btn_edit_address, <void*>consts.SIPPROXY)
    ui.btn_ping_sip.callback(on_btn_ping, <void*>consts.SIPPROXY)
    ui.btn_ice_storage.callback(on_btn_edit_address, <void*>consts.ICESTORAGEURL)
    ui.btn_ping_ice.callback(on_btn_ping, <void*>consts.ICESTORAGEURL)
    ui.btn_stun_server.callback(on_btn_edit_address, <void*>consts.STUNSERVER)
    ui.btn_ping_stun.callback(on_btn_ping, <void*>consts.STUNSERVER)
    ui.btn_turn_server.callback(on_btn_edit_address, <void*>consts.TURNSERVER)
    ui.btn_ping_turn.callback(on_btn_ping, <void*>consts.TURNSERVER)
    ui.btn_ntp_server.callback(on_btn_edit_address, <void*>consts.NTPSERVER)
    ui.btn_ping_ntp.callback(on_btn_ping, <void*>consts.NTPSERVER)
    # Group Experts
    ui.btn_local_proxy.callback(on_btn_edit_address, <void*>consts.LOCPROXYADDR)
    ui.btn_ping_local_proxy.callback(on_btn_ping, <void*>consts.LOCPROXYADDR)
    ui.btn_upload_server.callback(on_btn_edit_address, <void*>consts.UPLOADSERVER)
    ui.btn_ping_upload_server.callback(on_btn_ping, <void*>consts.UPLOADSERVER)
    ui.btn_sshd.callback(on_btn_sshd, NULL)
    #ui.browse_archive.filter("[a-zA-Z0-9]*")
    ui.browse_archive.load("archive")
    ui.browse_archive.remove(1) # hide ../
    ui.btn_add_file.callback(on_btn_addfiles, NULL)
    ui.btn_remove_file.callback(on_btn_removefiles, NULL)
    ui.btn_show_selected.callback(on_btn_show_selected, NULL)
    ui.btn_upload.callback(on_btn_upload, NULL)
    # Group Password
    ui.btn_root_pw.callback(on_btn_root_pw, NULL)
    # Group Reset
    ui.btn_restart.callback(on_btn_restart, <void*>str_save_and_restart)
    ui.btn_reconfig.callback(on_btn_restart, <void*>str_save_and_reconfig)
    ui.btn_reboot.callback(on_btn_restart, <void*>'reboot')
    ui.btn_shutdown.callback(on_btn_restart, <void*>'shutdown')
    ui.btn_nxcal.callback(on_btn_nxcal, NULL)
    ui.btn_zid_reset.callback(on_btn_zid_reset, NULL)
    ui.btn_fac_reset.callback(on_btn_fac_reset, NULL)
    #Group SysInfo
    ui.btn_zsipos_cfg.callback(on_btn_sysinfo, <void*>"zsipos.cfg")
    ui.btn_zsipos_log.callback(on_btn_sysinfo, <void*>"zsipos.log")
    ui.btn_nohup_out.callback(on_btn_sysinfo, <void*>"nohup.out")
    ui.btn_ifconfig.callback(on_btn_ifconfig, NULL)
    ui.btn_resolv_conf.callback(on_btn_sysinfo, <void*>"/etc/resolv.conf")
    ui.btn_messages.callback(on_btn_sysinfo, <void*>"/var/log/messages")
    gitout_init()
    gitversions_init()
    ui.btn_show_git.callback(on_btn_show_git, NULL)
    # EditButtons
    ui.btn_address_back.callback(on_btn_address_back, NULL)
    ui.btn_address_ok.callback(on_btn_address_ok, NULL)
    ui.btn_address_next.callback(on_btn_address_next, NULL)
    ui.btn_address_cancel.callback(on_btn_address_cancel, NULL)
    ui.btn_address_warn.callback(on_btn_address_warn, NULL)
    # Keyboard callbacks
    keyboard_init()
    if infstr:
        warn(infstr)

    log.info("... finished")
# configui_init

#
# GUI class
#
cdef extern from "gui.cxx":

    cdef cppclass CONFIGUI:

        Fl_Double_Window*   window
        Fl_Button*          btn_back
        Fl_Button*          btn_help
        Fl_Button*          btn_warn
        Fl_Tabs*            tab_config
        # IP Config
        Fl_Group*           group_ip
        Fl_Group*           group_btn_dhcp
        Fl_Round_Button*    btn_dhcp
        Fl_Round_Button*    btn_static_ip
        Fl_Group*           group_btn_dns
        Fl_Round_Button*    btn_auto_dns
        Fl_Round_Button*    btn_static_dns
        Fl_Group*           group_static_ip
        Fl_Output*          btn_ext_phone
        Fl_Output*          btn_gateway
        Fl_Output*          btn_subnet_mask
        Fl_Button*          btn_ping_gateway
        Fl_Group*           group_dns
        Fl_Output*          btn_dns_server
        Fl_Button*          btn_ping_dns
        # Server
        Fl_Group*           group_server
        Fl_Output*          btn_sip_proxy
        Fl_Button*          btn_ping_sip
        Fl_Output*          btn_ice_storage
        Fl_Button*          btn_ping_ice
        Fl_Output*          btn_stun_server
        Fl_Button*          btn_ping_stun
        Fl_Output*          btn_turn_server
        Fl_Button*          btn_ping_turn
        Fl_Output*          btn_ntp_server
        Fl_Button*          btn_ping_ntp
        # Logging
        Fl_Group*           group_log
        Fl_Check_Button*    log_external
        Fl_Check_Button*    log_local
        Fl_Check_Button*    log_full
        Fl_Check_Button*    log_cc_events
        Fl_Check_Button*    log_cc_messages
        Fl_Check_Button*    log_bm_events
        Fl_Check_Button*    log_timers
        Fl_Check_Button*    log_sip_proctime
        Fl_Check_Button*    log_sip_debug_delay
        Fl_Check_Button*    log_zrtp_events
        Fl_Check_Button*    log_zsession_events
        Fl_Check_Button*    log_ice
        Fl_Check_Button*    log_dtmf
        Fl_Counter*         log_level
        # Experts
        Fl_Group*           group_experts
        Fl_Output*          btn_local_proxy
        Fl_Button*          btn_ping_local_proxy
        Fl_Output*          btn_upload_server
        Fl_Button*          btn_ping_upload_server
        Fl_Check_Button*    btn_skipzrtp1
        Fl_Check_Button*    btn_sshd 
        Fl_File_Browser*    browse_archive
        Fl_Button*          btn_add_file
        Fl_Button*          btn_remove_file
        Fl_Button*          btn_upload
        Fl_Button*          btn_show_selected

        # Password
        Fl_Group*           group_passwd
        Fl_Button*          btn_root_pw
        # Reset
        Fl_Group*           group_reset
        Fl_Button*          btn_restart
        Fl_Button*          btn_reconfig
        Fl_Button*          btn_reboot
        Fl_Button*          btn_shutdown
        Fl_Button*          btn_nxcal
        Fl_Button*          btn_zid_reset
        Fl_Button*          btn_fac_reset
        # Sys Info
        Fl_Button*          btn_zsipos_cfg
        Fl_Button*          btn_zsipos_log
        Fl_Button*          btn_nohup_out
        Fl_Button*          btn_ifconfig
        Fl_Button*          btn_resolv_conf
        Fl_Button*          btn_messages
        Fl_Button*          btn_show_git
        Fl_Output*          out_git_magic

        # Save
        Fl_Double_Window*   winSave
        #Fl_Group*           group_save
        Fl_Button*          btn_save_and_restart
        Fl_Button*          btn_save
        Fl_Button*          btn_cancel
        Fl_Box*             box_restart

        # Help
        Fl_Double_Window*   winHelp
        Fl_Button*          btn_help_back
        Fl_Text_Display*    helpDisplay
        Fl_Text_Buffer*     helpTextBuffer
        Fl_Text_Buffer*     helpStyleBuffer

        # EditAddress
        Fl_Double_Window*   winEditAddress
        Fl_Group*           addressgroup
        Fl_Group*           ipgroup
        Fl_Input*           input_text
        Fl_Button*          btn_address_back
        Fl_Button*          btn_address_ok
        Fl_Button*          btn_address_next
        Fl_Button*          btn_address_cancel
        Fl_Button*          btn_address_warn
        # Url
        Fl_Round_Button*    btn_https

        # Keyboard Funktionskeys
        Fl_Group*           keyboardgroup_func
        Fl_Button*          key_del
        Fl_Button*          key_back
        Fl_Button*          key_forward
        Fl_Button*          key_123
        Fl_Button*          key_abc
        Fl_Button*          key_shift

        # Keyboard alpha_lower
        Fl_Group*           keyboardgroup_alpha
        Fl_Button*          key_dot_alpha
        Fl_Button*          key_comma_alpha

        Fl_Group*           keyboardgroup_alpha_lower
        Fl_Button*          key_a
        Fl_Button*          key_b
        Fl_Button*          key_c
        Fl_Button*          key_d
        Fl_Button*          key_e
        Fl_Button*          key_f
        Fl_Button*          key_g
        Fl_Button*          key_h
        Fl_Button*          key_i
        Fl_Button*          key_j
        Fl_Button*          key_k
        Fl_Button*          key_l
        Fl_Button*          key_m
        Fl_Button*          key_n
        Fl_Button*          key_o
        Fl_Button*          key_p
        Fl_Button*          key_q
        Fl_Button*          key_r
        Fl_Button*          key_s
        Fl_Button*          key_t
        Fl_Button*          key_u
        Fl_Button*          key_v
        Fl_Button*          key_w
        Fl_Button*          key_x
        Fl_Button*          key_y
        Fl_Button*          key_z

        Fl_Group*           keyboardgroup_alpha_upper
        Fl_Button*          key_A
        Fl_Button*          key_B
        Fl_Button*          key_C
        Fl_Button*          key_D
        Fl_Button*          key_E
        Fl_Button*          key_F
        Fl_Button*          key_G
        Fl_Button*          key_H
        Fl_Button*          key_I
        Fl_Button*          key_J
        Fl_Button*          key_K
        Fl_Button*          key_L
        Fl_Button*          key_M
        Fl_Button*          key_N
        Fl_Button*          key_O
        Fl_Button*          key_P
        Fl_Button*          key_Q
        Fl_Button*          key_R
        Fl_Button*          key_S
        Fl_Button*          key_T
        Fl_Button*          key_U
        Fl_Button*          key_V
        Fl_Button*          key_W
        Fl_Button*          key_X
        Fl_Button*          key_Y
        Fl_Button*          key_Z

        # Keyboard numerisch
        Fl_Group*           keyboardgroup_num
        Fl_Button*          key_1
        Fl_Button*          key_2
        Fl_Button*          key_3
        Fl_Button*          key_4
        Fl_Button*          key_5
        Fl_Button*          key_6
        Fl_Button*          key_7
        Fl_Button*          key_8
        Fl_Button*          key_9
        Fl_Button*          key_0
        Fl_Button*          key_at
        Fl_Button*          key_colon
        Fl_Button*          key_semicolon
        Fl_Button*          key_underscore
        Fl_Button*          key_minus
        Fl_Button*          key_hash
        Fl_Button*          key_lparenthesis
        Fl_Button*          key_rparenthesis
        Fl_Button*          key_slash
        Fl_Button*          key_plus
        Fl_Button*          key_dot_num
        Fl_Button*          key_comma_num
        Fl_Button*          key_question
        Fl_Button*          key_exclamation
        Fl_Button*          key_singlequote
        Fl_Button*          key_doublequote


        CONFIGUI() nogil
