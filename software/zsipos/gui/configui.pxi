# SPDX-FileCopyrightText: 2020 Esther Bergter <esther.bergter@vipcomag.de>
#
# SPDX-License-Identifier: GPL-3.0-or-later

"""
Copyright (C) 2020 Esther Bergter

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
# Version 1.1

debuginfo = True

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
#import urllib.request

# private modules
from gitversions import gitversions,gitdates
from iputils import split_host_port
from utils import getGitMagic,gitFormat,tstr,issel4

cdef CONFIGUI* configui

cdef Fl_Text_Buffer* helpTextBuffer
cdef Fl_Text_Buffer* updateInfoBuffer
cdef Fl_Text_Buffer* updateProgressBuffer

cdef str constopt   # consts-Option, die gerade bearbeitet wird

cdef str already_current = 'you already have the current version'
cdef str section = 'gmitm'
cdef str str_ip_config = 'Ip Config'
cdef str alternate_partition='/tmp/alternate_partition'
cdef str versioncounter_path = '/versioncount'
cdef str versiontext_path = '/version.txt'
cdef str mountbase = '/dev/mmcblk0p'
cdef str partition_path = '/proc/device-tree/chosen/zsipos,partition'
cdef str bootversion_path = '/proc/device-tree/chosen/zsipos,boot-version'
cdef str update_file = 'update.txt'
cdef str updatetar_path = 'packages/'
cdef str testversion_path = 'testversion'
cdef str copylist_path = '/tmp/alternate_partition/root/config_list.txt'
cdef str local_archive_path = 'archive'
cdef str current_archive = local_archive_path
cdef str alternate_archive_path = '/tmp/alternate_partition/root/archive'
cdef str empty_label = 'archive                                                            '
cdef str str_hexdigest_matches = 'hexdigest matches, ok\n'
cdef str str_hexdigest_ignored = 'hexdigest ignored, ok\n'
#cdef str str_hexdigest_wrong = 'hexdigest does not match, not ok'
cdef str str_hexdigest_canceled = 'no hexdigest given, not ok\n'
cdef str str_update_started = 'Update started ...\n'
cdef str str_update_canceled = 'Update canceled\n'
cdef str str_update_failed = 'Update failed\n'
cdef str str_update_completed = 'Update completed\n'
cdef str str_download_started = 'Download started ...\n'
cdef str str_download_canceled = 'Download canceled\n'
cdef str str_download_failed = 'Download failed\n'
cdef str str_download_completed = 'Download done.\n'
cdef str str_unpack_started = 'Unpacking ...\n'
cdef str str_unpack_canceled = 'Unpack canceled\n'
cdef str str_unpack_failed = 'Unpack failed\n'
cdef str str_unpack_completed = 'Unpack done.\n'
cdef str str_copy_config = 'copying configuration, please wait\n'
cdef str str_copy_config_done = 'copy configuration done.\n'

cdef str str_update_reboot_information = '\nNOTE: If reboot should fail, press display until it turns black. Device returns to current version.'
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
cdef str str_altmount = ''
cdef str str_updateVersion = ''       # aus update.txt
cdef str str_updateFilename = ''      # aus update.txt
cdef str str_update_hexdigest = ''    # checksum des downloads
cdef sendfiles = set()

cdef int partition_number = 0 
cdef int current_versioncounter = 0
cdef int alternate_versioncounter = 0

cdef bool hexdigest_matches = False
cdef bool user_hit_cancel_button = False
cdef bool UpdateFailed = False
cdef bool UpdateHalted = False
cdef bool stable = False            # configui not initialized yet

# keep consistent with consts.py Logging
logconsts = [ consts.LOGEXT, consts.LOGLOC, consts.LOGFULLMESSAGE, 
  consts.LOGCCEVENTS, consts.LOGCCMESSAGES, consts.LOGBMEVENTS,
  consts.LOGSIPTIMING, consts.LOGTIMERS, consts.SIPDELAY, consts.LOGZRTPCB,
  consts.LOGZSESSIONCB, consts.LOGICE, consts.LOGDTMF, consts.PJLOGLEVEL ]


""" Callbacks """

# application MAINUI
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


cdef void on_config_close(Fl_Widget* widget, void *data) with gil:
    configui.window.hide()

# CONFIGUI 

# Config utils
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
    if myopt == consts.LOCPROXYADDR:
        ifnr = 1
    else:
        ifnr = 0
    do_ping(val, ifnr)
    
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


# main window
cdef void on_btn_back(Fl_Widget* widget, void *data) with gil:
    do_back()

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
    configui.txt_helpDisplay.copy_label("Help")
    configui.winHelp.show()

cdef void on_btn_warn(Fl_Widget* widget, void *data) with gil:
    configui.btn_warn.hide()
    configui.tab_config.show()

# Config TabGroup
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

# callback Config Groups
# Server

# callback Config Groups
# Log
cdef void on_btn_logsettings(Fl_Widget* widget, void *data) with gil:
    configui.winLogSettings.show()

cdef void on_btn_addfile(Fl_Widget* widget, void *cfdata) with gil:
    """ add/remove nohup.out, zsipos.log """
    myitem = <Fl_Button*>cfdata
    myfile = get_label(myitem)
    if get_value(myitem):
        log.info("on_btn_addfile: add %s" %(myfile,))
        add_file(myfile)
    else:
        log.info("on_btn_addfile: remove %s" %(myfile,))
        remove_file(myfile)

cdef void on_browser_archive_click(Fl_Widget* widget, void *data) with gil:
    """ add/remove files from archive """
    global sendfiles
    
    #log.info("on_browser_archive_click: sendfiles %s" %(sendfiles))
    size = configui.browse_archive.size()
    for index in range(1, size+1):
        filename = configui.browse_archive.text(index)
        relfile = os.path.join(current_archive, filename)
        if configui.browse_archive.selected(index):
            if relfile in sendfiles:
                log.info("on_browser_archive_click: remove %s" %(filename,))
                remove_file(relfile)
                configui.browse_archive.select(index,0) # deselect
            else:
                log.info("on_browser_archive_click: add %s" %(filename,))
                add_file(relfile)
        else:
            if relfile in sendfiles: 
                configui.browse_archive.select(index,1) # select

cdef void on_btn_upload(Fl_Widget* widget, void *data) with gil:
    add_stdfiles()
    if len(sendfiles) > 1: # more files than Manifest.txt
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
        make_Manifest()
        do_send()
    else:
        warn('no files selected')

cdef void on_btn_alternate_archive(Fl_Widget* widget, void *data) with gil:
    """ switch between local and alternate archive """
    global current_archive

    if get_value(configui.btn_alternate_archive) == 0:   # lokales archiv
        current_archive=local_archive_path
        configui.browse_archive.copy_label(empty_label) # erase longer value
    else:                                                # alternatives archiv
        if mount_alternate(False): # kein output
            if not os.path.exists(alternate_archive_path):
                os.mkdir(alternate_archive_path)
            current_archive=alternate_archive_path
            configui.browse_archive.copy_label(alternate_archive_path)
        else:
            current_archive=local_archive_path
            configui.browse_archive.copy_label(empty_label) # erase longer value
    configui.browse_archive.load(current_archive)
    configui.browse_archive.remove(1) # hide ../
    # now mark all selected files
    size = configui.browse_archive.size()
    for index in range(1, size+1):
        filename = configui.browse_archive.text(index)
        relfile = os.path.join(current_archive, filename)
        if relfile in sendfiles:
            configui.browse_archive.select(index,1)

# callback Config Groups
# Experts
cdef void on_btn_autosshd(Fl_Widget* widget, void *data) with gil:
    #debug(os.uname())
    if get_value(configui.btn_autosshd) == 1:
        if issel4():
            os.system('ln -s /etc/init.d/sshd /etc/init.d/S50sshd')
        else:
            log.info('autosshd requested on')
    else:
        if issel4():
            os.system('rm /etc/init.d/S50sshd')
        else:
            log.info('autosshd requested off')

cdef void on_btn_sshd(Fl_Widget* widget, void *data) with gil:
    #debug(os.uname())
    if get_value(configui.btn_sshd) == 0:
        if issel4():
            os.system('/etc/init.d/sshd stop')
        else:
            log.info('sshd requested stop')
    else:
        if issel4():
            os.system('/etc/init.d/sshd start')
        else:
            log.info('sshd requested start')


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
    if issel4():
        #debug('factory reset')
        for file in (consts.CFGFILE, consts.ZIDFILE, consts.NDBFILE):
            if os.path.isfile(file):
                log.info("remove "+file)
                os.remove(file)
        log.info("factory reset, reboot system")
        os.system('reboot')
    else:
        log.info('factory reset requested')

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

# callback Config Groups
# Sysinfo
cdef void on_btn_sysinfo(Fl_Widget *widget, void *data) with gil:
    show_sysinfo(<str>data)

cdef void on_btn_ifconfig(Fl_Widget *widget, void *data) with gil:
    show_ifconfig()

cdef void on_btn_show_git(Fl_Widget* widget, void *data) with gil:
    global configui
    global helpTextBuffer

    helpTextBuffer.text(str_gitversions)
    configui.txt_helpDisplay.copy_label("gitversion")
    configui.winHelp.show()

# callback Config Groups
# Update
cdef void on_btn_boot_version(Fl_Widget* widget, void *data) with gil:

    if get_value(configui.btn_boot_current) == 1:   # current 
        cfdict['BOOT_CURRENT'] = True
    else:                                    # alternate
        cfdict['BOOT_CURRENT'] = False

cdef void on_btn_update_info(Fl_Widget* widget, void *data) with gil:
    if config_has_changed():
        do_save_cfg()
    update_update_text()
    configui.winUpdateInfo.show()
    
#########################################
# Windows
#########################################
# WinSave
cdef void on_btn_save_and_restart(Fl_Widget* widget, void *data) with gil:

    do_save_cfg()
    configui.winSave.hide()
    configui.window.hide()
    do_restart(get_label(configui.btn_save_and_restart))


cdef void on_btn_save_ok(Fl_Widget* widget, void *data) with gil:
    #debug("on_btn_save")
    do_save_cfg()
    configui.winSave.hide()
    configui.window.hide()


cdef void on_btn_save_cancel(Fl_Widget* widget, void *data) with gil:

    configui.winSave.hide()
    configui.window.hide()

# WinHelp
cdef void on_btn_help_back(Fl_Widget* widget, void *data) with gil:
    configui.winHelp.hide()


# WinEditAddress
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
    #debug("estep = %d" % (estep,))
    
    if address_cache(params):
        #debug("address_cache ok")
        estep += 1
        #debug("address_cache: estep = %d" % (estep,))

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

# winLogSettings
cdef void on_btn_logsettings_back(Fl_Widget* widget, void *data) with gil:
    configui.winLogSettings.hide()

# winUpdateInfo
cdef void on_btn_updateinfo_back(Fl_Widget* widget, void *data) with gil:
    configui.winUpdateInfo.hide()

cdef void on_btn_updateinfo_ok(Fl_Widget* widget, void *data) with gil:
    configui.winUpdateInfo.hide()
    configui.winUpdateSure.show()
    
# winUpdateSure
cdef void on_btn_updatesure_cancel(Fl_Widget* widget, void *data) with gil:
    configui.winUpdateSure.hide()

cdef void on_btn_updatesure_ok(Fl_Widget* widget, void *data) with gil:
    global user_hit_cancel_button
    global UpdateHalted

    user_hit_cancel_button = False
    UpdateHalted = False
    UpdateFailed = False
    configui.winUpdateSure.hide()
    configui.btn_updateprogress_reboot.deactivate()
    configui.btn_updateprogress_cancel.activate()
    configui.winUpdateProgress.show()
    configui.winUpdateProgress.wait_for_expose()
    do_update1()

# winUpdateProgress
cdef void on_btn_updateprogress_cancel(Fl_Widget* widget, void *data) with gil:
    global user_hit_cancel_button
    debug("user hit cancel")
    if UpdateFailed or UpdateHalted:
        configui.winUpdateProgress.hide()
    else:
        user_hit_cancel_button = True
        configui.btn_updateprogress_cancel.deactivate()
    
cdef void on_btn_updateprogress_reboot(Fl_Widget* widget, void *data) with gil:
    do_restart('reboot')

#cdef void on_btn_updateprogress_back(Fl_Widget* widget, void *data) with gil:
#    configui.winUpdateProgress.hide()

# winEditHex
cdef void on_btn_hex_ignore(Fl_Widget* widget, void *data) with gil:
    global hexdigest_matches
    
    hexdigest_matches = True
    configui.winEditHex.hide()
    to_updateprogress(str_hexdigest_ignored)
    do_update2()

cdef void on_btn_hex_cancel(Fl_Widget* widget, void *data) with gil:
    global hexdigest_matches
    global UpdateFailed
    
    hexdigest_matches = False
    UpdateFailed = True
    configui.winEditHex.hide()
    to_updateprogress(str_hexdigest_canceled)
    to_updateprogress(str_update_failed)

cdef void on_btn_hex_ok(Fl_Widget* widget, void *data) with gil:
    global hexdigest_matches
    
    if compare_hexdigest():
        hexdigest_matches = True
        configui.winEditHex.hide()
        to_updateprogress(str_hexdigest_matches)
        do_update2()
    else:
        hexdigest_matches = False
        configui.keyboardgroup_hex_func.hide()
        configui.keyboardgroup_hex.hide()
        configui.btn_hex_warn.show()

cdef void on_btn_hex_warn(Fl_Widget* widget, void *data) with gil:
    configui.keyboardgroup_hex_func.show()
    configui.keyboardgroup_hex.show()
    configui.btn_hex_warn.hide()

# Keyboard Hex
cdef void on_hexkey(Fl_Widget* widget, void *cfdata) with gil:
    val = <str>cfdata
    
    configui.input_hex.insert(val, 0)
    collapsed_pos = collapse_hexpos(get_position(configui.input_hex))
    hexbuf = collapse_hexbuf(get_value(configui.input_hex))
    restore_hexedit(hexbuf, collapsed_pos)
    configui.input_hex.take_focus()

cdef void on_hexdel(Fl_Widget* widget, void *data) with gil:
    configui.btn_hex_warn.hide()
    collapsed_pos = collapse_hexpos(get_position(configui.input_hex)) -1
    hexbuf = collapse_hexbuf(get_value(configui.input_hex))
    hexbuf = cut(hexbuf, collapsed_pos)
    restore_hexedit(hexbuf, collapsed_pos)
    configui.input_hex.take_focus()

cdef void on_hexback(Fl_Widget* widget, void *cfdata) with gil:
    i = <Fl_Input_*>cfdata
    configui.btn_hex_warn.hide()
    pos = get_position(i)
    configui.input_hex.position(pos-1, pos-1)
    configui.input_hex.take_focus()

cdef void on_hexforward(Fl_Widget* widget, void *cfdata) with gil:
    i = <Fl_Input_*>cfdata
    pos = get_position(i)
    configui.input_hex.position(pos+1, pos+1)
    configui.input_hex.take_focus()


'''
###########################################################################
# Python
###########################################################################
'''
editcache = []

# Python Functions (alphabetical)
def add_file(filename):
    global sendfiles;

    if os.path.isfile(filename):
        if filename not in sendfiles:
            sendfiles.add(filename)
    log.info("add_file: sendfiles %s" %(sendfiles))
    
def add_file_snapshot(filename):
    newname = '_' + filename
    shutil.copy2(filename, newname)
    sendfiles.add(newname)

def add_stdfiles():
    global sendfiles;
    sendfiles.add('Manifest.txt')
    if get_value(configui.btn_nohup):
        add_file_snapshot('nohup.out')
    if get_value(configui.btn_zsiposlog):
        add_file_snapshot('zsipos.log')

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
        debug("splitparams %s, clen %d" %(splitparams, clen))
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
                elif clen == 4:
                    concatval = concatfunc(editvals[estep], editvals[estep+1], editvals[estep+2], editvals[estep+3])
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

def altversfilename(source):
    """ magic absolute path """
    return (os.path.join(alternate_partition, source[1 if source.startswith('/') else 0 :]))
    
def bootversion_init():
    try: 
        with open(bootversion_path, 'r') as f:
            for l in f.readlines():
                configui.out_bootversion.value(l.strip())
                break
    except:
        configui.out_bootversion.value('unknown bootversion')     

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

def check_update(ret):
    """ return true if update can continue, else false """
    global UpdateHalted
    global UpdateFailed

    Fl.check()
    if UpdateHalted:
        debug("check_update found UpdateHalted")
        return False
    if UpdateFailed:
        debug("check_update found UpdateFailed")
        return False
    elif user_hit_cancel_button:
        debug("check_update found user_hit_cancel_button")
        to_updateprogress(str_update_canceled)
        UpdateHalted = True
        configui.winUpdateProgress.hide()
        return False
    elif not ret:
        debug("check_update found ret not ok")
        to_updateprogress(str_update_failed)
        UpdateFailed = True
        configui.btn_updateprogress_cancel.activate()
        return False
    else:
        debug("check_update ok")
        return True

def cfg_cleanup():
    if cfdict[consts.EXTUSEDHCP]:
        #cfdict[consts.EXTPHONEADDR] = "" # NEIN! brauche ich
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

def cfg_hide_externalPhoneAddress():
    ''' remove form config just before writing cfg '''
    if cfdict[consts.EXTUSEDHCP]:
        config.remove_option(consts.SECTION, consts.EXTPHONEADDR)

def cfg_restore_externalPhoneAddress():
    ''' restore extPhoneAddress after cfg is written'''
    if cfdict[consts.EXTUSEDHCP]:
        config.set(consts.SECTION, consts.EXTPHONEADDR, cfdict[consts.EXTPHONEADDR])

def clearpw():
    oldpw = ""
    newpw = ""
    newpw2 = ""

def clearsendfiles():
    global sendfiles

    sendfiles = set()
    size = configui.browse_archive.size()
    for index in range(1, size+1):
        configui.browse_archive.select(index,0)

def collapse_hexbuf(whitestring):
    return "".join(whitestring.split())
    
def collapse_hexpos(whitepos):
    blocklen = 5
    blocks = int(whitepos/blocklen)
    #debug("whitepos %d, blocks %d" % (whitepos, blocks))
    return whitepos-blocks
    
def compare_hexdigest():
    """ compare mystring with str_update_hexdigest """
    mystring = collapse_hexbuf(get_value(configui.input_hex))
    debug(mystring)
    if mystring == str_update_hexdigest.upper():
        return True
    else:
        return False
    
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

def concat_url_path(scheme, ip, port, path):
    #debug("scheme %s, ip %s, port %s, path %s" % (scheme, ip, port, path))
    if port is None or len(port) == 0:
        if is_valid_hostname(ip) or is_valid_ipv4_address(ip):
            concat = "%s://%s%s" %(scheme, ip, path)
        elif is_valid_ipv6_address(ip):
            concat = "%s://[%s]%s" % (scheme, ip, path)
        else:
            log.error("concat_url failed")
            concat = None
    else:
        if is_valid_hostname(ip) or is_valid_ipv4_address(ip):
            concat = "%s://%s:%s%s" %(scheme, ip, port, path)
        elif is_valid_ipv6_address(ip):
            concat = "%s://[%s]:%s%s" % (scheme, ip, port, path)
        else:
            log.error("concat_url failed")
            concat = None
            
    return concat
# concat_url_path

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
    # Boot Version
    if current_versioncounter > alternate_versioncounter:
        cfdict['BOOT_CURRENT'] = True
        olddict['BOOT_CURRENT'] = True
    else:
        cfdict['BOOT_CURRENT'] = False
        olddict['BOOT_CURRENT'] = False

    #debug_dict("config_to_dict")
# config_to_dict

def config_valid(name):
    """ True if cfdict[name] is defined """
    return True if name in cfdict and cfdict[name] else False

def copy_configs():
    """ copy files in config-list to alternate filesystem """
    if os.path.exists(copylist_path):
        to_updateprogress(str_copy_config)
        with open(copylist_path, 'r') as f:
            for l in f.readlines():
                source = l.strip()
                if '*' in source:
                    for fn in glob.glob(source):
                        copy_file(fn)
                else:
                    copy_file(source)
        to_updateprogress(str_copy_config_done)
        return True
    else:
        #log.error("copy_configs: %s not found" % (copylist_path,))
        err_to_updateprogress("copy_configs: %s not found\n" % (copylist_path,))
        return False
        
def copy_file(source):
    """ copy source to alternate_partition, generate dirs as needed """
    #to_updateprogress("copy_file source %s\n" % (source, ))
    if os.path.exists(source):
        dest = altversfilename(source)
        log.info("copy_file dest %s" % (dest, ))
        (head, tail) = os.path.split(dest)
        if not os.path.isdir(head):
            os.mkdir(head)
        try:
            shutil.copy2(source,dest,follow_symlinks=False)
        except PermissionError:
            log.error("cannot copy(%s,%s), permission denied" % (source, dest))
            if issel4():
                raise
    
def cut(s, i):
    """ cut char at pos i from string """
    debug("cut %s %d" % (s,i))
    if i < 0:
        return s
    
    result = s[:i] + s[i+1:]
    debug("result %s" % (result,))
    return result
    
def debug(string):
    if not debuginfo: return
    log.info(string)


def debug_dict(string, mydict=None):
    if not debuginfo: return
    debug(string)
    if mydict is None:
        mydict = cfdict
    for key in sorted(mydict.iterkeys()):
        s = '{}: {}'.format(key, mydict[key])
        debug(s)
    debug("end of cfdict..............................")

def debug_editcache(string):
    if not debuginfo: return
    debug(string)


def dict_to_config():
    """ copy dict items back to config. """

    #debug_dict("dict_to_config")
    config[consts.SECTION] = {}
    for key, value in cfdict.items():
        if key == 'AutoDns' or key == 'BOOT_CURRENT':
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

def do_ping(host, ifnr):
    global helpTextBuffer

    #debug("do_ping: host %s" % (host,))
    configui.txt_helpDisplay.copy_label("ping")
    out = "ping %s ...\n" % (host,)
    helpTextBuffer.text(out)
    configui.winHelp.show()
    configui.winHelp.wait_for_expose()
    configui.winHelp.flush()

    try:
        if issel4():
            out += subprocess.check_output(["sel4iptool", "eth"+str(ifnr), "ping", host, "2"], stderr=subprocess.STDOUT, encoding="utf8")
        else:
            out += subprocess.check_output(["ping", "-c", "2", host], stderr=subprocess.STDOUT, encoding="utf8")
    except CalledProcessError as e:
        if len(e.output):
            out += e.output
        else:
            out += str(sys.exc_info()[1])
    finally:
        helpTextBuffer.text(out)
    configui.winHelp.flush()


def do_restart(restart_type):
    """ restart application """
    if issel4():
        os.sync()
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
    else:
        log.info("%s requested" % (restart_type,))

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
    write_versioncount()
    os.sync()

import io

LOGSEND_GZIP    = False
LOGSEND_CHUNKED = False

def do_send_http(url, files):
    
    def to_upload_progress(s):
        helpTextBuffer.append(s)
        configui.winHelp.flush()
    
    def update_percent(percent):
        nonlocal mypos, lastpos, last_percent
        
        if (percent > last_percent):
            if (percent > 100):
                percent = 100
            last_percent = percent
            helpTextBuffer.replace(mypos, lastpos, "%d%% " % (percent,))
            lastpos = helpTextBuffer.length()
            configui.winHelp.flush()
            
    def safe_del(name):
        if os.path.exists(name):
            os.remove(name)

    try:    
        configui.txt_helpDisplay.copy_label("upload")
        helpTextBuffer.text("uploading logfiles started...\n")
        configui.btn_help_back.hide()                                                     
        configui.winHelp.show()
        logpack_name = 'logpack.tgz'
        chunk_size = 1024 * 8
        last_percent = -1
        total_size = 0
        for i in files:
            total_size += 512 #file header
            file_size = os.path.getsize(i)
            blocks = file_size // 512
            if file_size % 512: #pad last block
                blocks += 1 
            total_size += blocks * 512
        total_size += 1024 #end blocks
        mypos = helpTextBuffer.length()
        lastpos = mypos+1
        proc_tar = subprocess.Popen(["tar",  "cf",  "-"] + list(files), stdout=subprocess.PIPE)
        if LOGSEND_GZIP: 
            
            class MyFile():
                """local helper class for progress display"""
                
                def __init__(self, name):
                    self.total_size = os.path.getsize(name)
                    self.done = 0
                    self.f = open(name, "rb")
                    
                def read(self, l=-1):
                    b = self.f.read(l)
                    self.done += len(b)
                    update_percent(100 * self.done // self.total_size)
                    return b
                
                def seek(self, offset, whence=io.SEEK_SET):
                    return self.f.seek(offset, whence)
                
                def tell(self):
                    return self.f.tell()
                
                def close(self):
                    self.f.close()
                    self.f = None
        
            to_upload_progress("preparing: ")
            proc_gzip = subprocess.Popen(["gzip -1 -c >" + logpack_name], stdin=subprocess.PIPE, shell=True)
            for block in iter(lambda: proc_tar.stdout.buffer.read(chunk_size), b""):
                proc_gzip.stdin.write(block)
                processed += len(block)
                update_percent(100 * processed // total_size)
            proc_tar.wait()
            proc_gzip.stdin.close()
            proc_gzip.wait()
            update_percent(100)
            to_upload_progress("done.\n")
            data = MyFile(logpack_name)
            
        else: # !LOGSEND_GZIP
            
            if LOGSEND_CHUNKED:
                
                def do_read():
                    """local helper function for progress display"""
                    nonlocal processed
                    block = proc_tar.stdout.read(chunk_size)
                    if block == b"":
                        proc_tar.wait()
                    processed += len(block)
                    update_percent(100 * processed // total_size)
                    return block
                
                processed = 0                
                data = iter(lambda: do_read(), b"")
            
            else: # !LOGSEND_CHUNKED
                
                class MyIter:                    
                    """local ierator class with len function for progess display"""
                    
                    def __init__(self):
                        self.done = 0
                    
                    def __iter__(self):
                        return self
                    
                    def __next__(self):
                        block = proc_tar.stdout.read(chunk_size)
                        if block == b"":
                            proc_tar.wait()
                            raise StopIteration
                        self.done += len(block)
                        update_percent(100 * self.done // total_size)
                        return block
                    
                    def __len__(self):
                        return total_size
                            
                data = MyIter()
                
        to_upload_progress("uploading: ")
        mypos = helpTextBuffer.length()
        lastpos = mypos+1
        last_percent = -1
        headers = {'content-type': 'application/octet-stream'}
        reply=requests.post(url, data=data, headers=headers)
        log.debug(reply.text)
        update_percent(100)
        clearsendfiles()
        to_upload_progress("done.\nall selected logfiles uploaded.")
                
    except Exception as e:
        to_upload_progress("\n\n**upload error**\n\n")
        to_upload_progress("(" + str(e) +")")
        raise
     
    finally:
        configui.btn_help_back.show()      
        safe_del("_zsipos.log")
        safe_del("_nohup.out")                                             
        safe_del("Manifest.txt")
        safe_del(logpack_name)

def do_send():
    user = cfdict[consts.UPLOADUSER]
    if user in ['http', 'https']:
        url = user + "://" + cfdict[consts.UPLOADSERVER] + ":" + str(cfdict[consts.UPLOADPORT])
        url += "/cgi-bin/recvlog.py"
        do_send_http(url, sendfiles)
        return
    myfiles = ' '.join(sendfiles)
    #debug('do_send')
    #debug(myfiles)
    # StrictHostKeyChecking=yes: dont ask but fail if not in known_hosts
    cpcmd = "tar -cf - %s |  /usr/bin/ssh -T %s@%s -p %s -o StrictHostKeyChecking=yes" % (
            myfiles, cfdict[consts.UPLOADUSER], cfdict[consts.UPLOADSERVER], str(cfdict[consts.UPLOADPORT]))
    log.info(cpcmd)
    configui.txt_helpDisplay.copy_label("upload")
    out = "uploading files\n  %s\n" % ('\n  '.join(sendfiles))
    helpTextBuffer.text(out)
    configui.winHelp.show() 
    configui.winHelp.wait_for_expose()

    try:
        exception_occurred = 0
        output = subprocess.check_output(cpcmd, stderr=subprocess.STDOUT, shell= True, encoding="utf8")
    except CalledProcessError as e:
        exception_occurred = 1
        output = e.output
    finally:
        log.info("send subprocess returned, exc_o= %d, output %s" %(exception_occurred, output ))
        if not exception_occurred:
            if output and len(output):
                out += output
            else:
                out += "send completed"
            clearsendfiles()
        else:
            out += output
        helpTextBuffer.text(out)
#do_send

def do_update1():
    ''' download tar, calc checksum '''
    try:
        updateProgressBuffer.text(str_update_started)
        configui.winUpdateProgress.flush()
        ret = download_update()
        if check_update(ret):
            if is_testversion():
                configui.btn_hex_back.show()
            else:
                configui.btn_hex_back.hide()
            configui.input_hex.value("")
            configui.winEditHex.show()
    except:
        logerrorexception()
        update_failed()
        
def do_update2():
    ''' mkfs, unpack tar, ... ''' 
    global UpdateHalted

    try:
        if check_update(hexdigest_matches):
            ret = untar_update()
            debug("do_update2: untar_update() returned %s" % ("True" if ret else "False")) 
        if check_update(ret):
            ret = copy_configs()
            debug("do_update2: copy_configs() returned %s" % ("True" if ret else "False")) 
        if check_update(ret):
            ret = write_alternateversion()
            debug("do_update2: write_alternateversion() returned %s" % ("True" if ret else "False")) 
        if issel4():
            umount_alternate(False) # True -> updateprogress
        if check_update(ret):
            to_updateprogress(str_update_completed)
            to_updateprogress(str_update_reboot_information)
            UpdateHalted = True     # update finished
            configui.btn_updateprogress_reboot.activate()
    except:
        logerrorexception()
        update_failed()
    
def download_update():
    ''' download update to fixed path '''
    global str_update_hexdigest
    
    cdef long dl
    cdef int done
    cdef int olddone
    cdef int mypos
    cdef int lastpos
    cdef long total_length
    
    if len(str_updateFilename) > 0:
        link = os.path.join(cfdict[consts.UPDATEURI], str_updateFilename)
        if not os.path.exists(updatetar_path):
            os.mkdir(updatetar_path)
        dest = os.path.join(updatetar_path, str_updateFilename)
    else:
        err_to_updateprogress("download filename not found\n")
        return False

    try:
        with open(dest, "wb") as f: # wb for binary data
            to_updateprogress(str_download_started)
            log.info("downloading %s to %s" % (link, dest))
            response = requests.get(link, stream=True)
            status_code = int(response.status_code)
            if status_code < 200 or status_code > 229:
                err_to_updateprogress("download %s failed, status %d\n" % (link, status_code))
                return False
            sha256 = hashlib.sha256()
            total = response.headers.get('content-length')
            if total is None: # no content-length header
                f.write(response.content)
                sha256.update(response.content)
            else:
                chunk_size = 1024 * 64
                dl = 0
                olddone = -1
                total_length = int(total)
                mypos = updateProgressBuffer.length()
                lastpos = mypos+1
                for data in response.iter_content(chunk_size=chunk_size): # sel4ip max chunk
                    Fl.check()
                    if user_hit_cancel_button:
                        debug("download_update_canceled")
                        break
                    dl += len(data)
                    f.write(data)
                    sha256.update(data)
                    done = 100 * dl // total_length
                    if done > olddone:
                        updateProgressBuffer.replace(mypos, lastpos, "%d%% " % (done,))
                        configui.winUpdateProgress.flush()
                        lastpos = updateProgressBuffer.length()
                        olddone = done
            if user_hit_cancel_button:
                to_updateprogress("\n%s" % (str_download_canceled,))
                return False
            elif check_update(True):
                str_update_hexdigest = sha256.hexdigest()
                debug(str_update_hexdigest)
                to_updateprogress(str_download_completed)
                return True
            else:
                return False
    except:
        logerrorexception()
        err_to_updateprogress(str_download_failed)
        return False
# download_update

def err_to_updateprogress(mytext):
    """ append to progress buffer and to log.error """
    if mytext.endswith('\n'):
        log.error(mytext[:-1])
    else:
        log.error(mytext)
    if stable:
        updateProgressBuffer.append(mytext)
        Display = configui.txt_updateprogress
        #debug("to_updateprogress: buffer_lenght %d" % (updateProgressBuffer.length(),))
        lines = Display.count_lines(1, updateProgressBuffer.length(), False)
        debug("Display.count_lines %d" % (lines, ))
        Display.scroll(lines, 0)
        configui.winUpdateProgress.flush()
        configui.winUpdateProgress.show()

def expand_hexbuf(s):
    blocks = int((len(s) + 3)/4)
    f=''
    for i in range(blocks):
        f+= s[4*i:4*i+4] + ("\n" if i%2 else ' ')
    return (f)
    
def expand_hexpos(mypos):
    blocks = int(mypos/4)
    #debug("mypos %d, blocks %d" % (mypos, blocks))
    return mypos+blocks
    
def get_alternate_mountname():
    """ build device with alternate partition number """
    global str_altmount
    
    if partition_number > 0 and partition_number < 3:
        alt_number = 3 - partition_number
    else:
        alt_number = -1
    if alt_number > 0:
        str_altmount = mountbase + str(alt_number)
        log.info("alternate device %s" % (str_altmount,))
    else:
        if issel4():
            log.error("no alternate device, invalid partition_number %d" %(partition_number,))
        else:
            log.info("no alternate device (not on sel4)" )

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

def get_http_file(url):
    ''' read http file and return content '''
    #with urllib.request.urlopen(url) as f:
    #    html = f.read().decode('utf-8')
    response = requests.get(url)
    html = response.content.decode('utf-8')
    return html

def get_versioncounter():
    ''' read current and alternate versioncounter '''
    global current_versioncounter
    global alternate_versioncounter
    
    try:
        with open(versioncounter_path, 'r') as f:
            for l in f.readlines():
                str_counter = l.strip()
                break
            current_versioncounter = int(str_counter)
    except:
        current_versioncounter = 1
    try:
        with open(altversfilename(versioncounter_path), 'r') as f:
            for l in f.readlines():
                str_counter = l.strip()
                break
            alternate_versioncounter = int(str_counter)
    except:
        alternate_versioncounter = 0
    log.info("current versioncounter: %d, alternate versioncounter %d" %(current_versioncounter, alternate_versioncounter))
        
def get_partition():
    ''' read partition number from device-tree '''
    global partition_number
    
    try:
        with open(partition_path, 'r') as f:
            for l in f.readlines():
                str_partition = l.strip().split('\x00')
                break
            partition_number = int(str_partition[0])
    except:
        if issel4():
            log.error("cannot read partition %s" % partition_path)
        partition_number = -1
    finally:
        log.info("partition %d" % (partition_number))

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
    debug("init_addresspar_editvals")
    for key in addresspar:
        debug(key)
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
    # logsettings
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
    #sshd
    found = 0
    if issel4():
        out = subprocess.Popen(["ps", "a",], stdout=subprocess.PIPE, encoding="utf8")
    else:
        out = subprocess.Popen(["ps", "ax",], stdout=subprocess.PIPE, encoding="utf8")
    for line in out.stdout:
        if line.find("/usr/sbin/sshd") >= 0:
            found = 1
            break
    if found:
        ui.btn_sshd.value(1)
        log.info("init: sshd is running")
    else:
        ui.btn_sshd.value(0)
        log.info("init: sshd not running")
    if os.path.isfile("/etc/init.d/S50sshd"):
        ui.btn_autosshd.value(1)
    else:
        ui.btn_autosshd.value(0)

def is_last_step(params):
    estep = params['estep']
    steps = params['steps']
    if estep+1 < steps:
        return False
    else:
        return True

def is_testversion():
    ''' look for file testversion '''
    if os.path.exists(testversion_path):
        return True
    else:
        return False
    
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

def is_valid_or_empty_port(testport):
    if testport is "":
        return True
    else:
        return is_valid_port(testport)

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

def keyboardhex_init():
    global configui

    # keyboardgroup_hex_func
    configui.key_hex_del.callback(on_hexdel, NULL)
    configui.key_hex_back.callback(on_hexback, configui.input_hex)
    configui.key_hex_forward.callback(on_hexforward, configui.input_hex)
    
    configui.key_h1.callback(on_hexkey, <void *>"1")
    configui.key_h2.callback(on_hexkey, <void *>"2")
    configui.key_h3.callback(on_hexkey, <void *>"3")
    configui.key_h4.callback(on_hexkey, <void *>"4")
    configui.key_h5.callback(on_hexkey, <void *>"5")
    configui.key_h6.callback(on_hexkey, <void *>"6")
    configui.key_h7.callback(on_hexkey, <void *>"7")
    configui.key_h8.callback(on_hexkey, <void *>"8")
    configui.key_h9.callback(on_hexkey, <void *>"9")
    configui.key_h0.callback(on_hexkey, <void *>"0")
    configui.key_hA.callback(on_hexkey, <void *>"A")
    configui.key_hB.callback(on_hexkey, <void *>"B")
    configui.key_hC.callback(on_hexkey, <void *>"C")
    configui.key_hD.callback(on_hexkey, <void *>"D")
    configui.key_hE.callback(on_hexkey, <void *>"E")
    configui.key_hF.callback(on_hexkey, <void *>"F")
    
def keyboard_init():
    global configui

    # keyboardgroup_func 
    configui.key_del.callback(on_del, NULL)
    configui.key_back.callback(on_back, configui.input_text)
    configui.key_forward.callback(on_forward, configui.input_text)
    configui.key_123.callback(on_change_keyboard, <void*>'123')
    configui.key_abc.callback(on_change_keyboard, <void*>'abc')
    configui.key_shift.callback(on_change_keyboard, <void*>'shift')
    configui.key_space.callback(on_key, <void *>" ")

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

def logerrorcaused_by(e):
    if hasattr(e, "caused_by"):
        log.error("CAUSED BY: %s", e.caused_by[1], exc_info = e.caused_by)
        logerrorcaused_by(e.caused_by[1])

def logerrorexception():
    global UpdateFailed
    global UpdateHalted

    info = sys.exc_info()
    err_to_updateprogress("EXCEPTION: %s\n" % (info[1]))
    UpdateFailed = True
    UpdateHalted = True
    logerrorcaused_by(info[1])

def make_Manifest():
    mversion = '0.1'
    file = open('Manifest.txt', 'w')
    file.write('Manifest Version %s\n' % (mversion))
    file.write('    Customer:  %s\n' % (cfdict[consts.UPLOADID], ))
    file.write('    Timestamp: %s\n' % (tstr(int(time()))))
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
#make_Manifest

def mkfs(devname):
    if not issel4():
        debug("mkfs skipped (not on sel4)")
        return True
    if len(devname) < 4:
        err_to_updateprogress("mkfs: invalid devname %s\n" % (devname,))
        return False
    return mysystemcall(["mkfs.ext4", devname], False) # True -> updateprogress
        
def mount_alternate(wantprogress):
    ''' mount the other partition '''
    if os.path.exists(alternate_partition):
        if os.path.ismount(alternate_partition):
            if wantprogress:
                to_updateprogress("alternate partition already mounted, ok\n")
            else:
                log.info("alternate partition already mounted, ok")
            return True
    else:
        os.mkdir(alternate_partition)
    if not issel4():
        debug("mount skipped (not on sel4)")
        return True
    if len(str_altmount) < 4:
        log.error("mount_alternate: invalid device %s" % (str_altmount,))
        if wantprogress:
            err_to_updateprogress("mount_alternate failed\n")
        else:
            log.error("mount_alternate failed\n")
        return False
    return mysystemcall(["mount", str_altmount, alternate_partition], wantprogress)

def mysystemcall(args, wantprogress):
    """ systemcall per subprocess, output to log and updateprogress """
    try:    
        exception_occurred = 0
        output = subprocess.check_output(args, stderr=subprocess.STDOUT, encoding="utf8")
    except CalledProcessError as e:
        exception_occurred = 1
        output = e.output
        log.error("%s subprocess returned, exc_o= %d, output %s" %(args[0], exception_occurred, output ))
    finally:
        if not exception_occurred:
            if output and len(output):
                out = output
            else:
                out = "%s completed" % (args[0],)
        else:
            out = output
        if wantprogress:
            out += "\n"
            to_updateprogress(out)
        else:
            log.info(out)
    if exception_occurred:
        return False
    else:
        return True
    
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
    # Logsettings
    for key in logconsts:
        if key in cfdict:
            if key in olddict:
                if olddict[key] != cfdict[key]:
                    log.info(key + " changed")
                    return str_save_and_restart
            else:
                log.info(key * " added")
                return str_save_and_restart
        else:
            if key in olddict:
                log.info(key + " deleted")
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

def parse(mytext):
    val = {}
    #debug("parse" + mytext)
    lines = mytext.split('\n')
    for l in lines:
        if l.startswith('#'):
            continue
        if ':' not in l:
            continue
        p,v=l.split(':',1)
        val[p.strip()]=v.strip()
    return val
  
def parse_update(update):
    global str_updateVersion, str_updateFilename
    val = parse(update)
    if 'Version' in val:
        str_updateVersion = val['Version']
    if 'Filename' in val:
        str_updateFilename = val['Filename']
    
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

    if filename in sendfiles:
        sendfiles.remove(filename)

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

def restore_hexedit(hexbuf, collapsed_pos):
    newvalue = expand_hexbuf(hexbuf)
    newpos = expand_hexpos(collapsed_pos)
    configui.input_hex.value(newvalue)
    configui.input_hex.position(newpos, newpos)

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
    Display=configui.txt_helpDisplay
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
    configui.txt_helpDisplay.copy_label("ifconfig")
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
    #debug('show_turn')
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

def split_url_path(input):
    debug("split_url_path " + input)
    re_host = re.compile('(http[s]?)://((\w+[\.]?)+)(:(\d+))?(/.*)')
    re_v6 = re.compile('(http[s]?)://\[([^\]]*)\](:(\d+))?(/.*)')
    re_v4 = re.compile('(http[s]?)://(\d[^:]*)(:(\d+))?(/.*)')
    result = re_host.search(input)
    if not result:
        #debug(v6)
        result = re_v6.search(input)
        if not result:
            #debug(v4)
            result = re_v4.match(input)
    if result is not None:
        if result.lastindex > 3:
            debug(result.group(1, 2, 5, result.lastindex))
            return result.group(1, 2, 5, result.lastindex)
    log.error("split_url_path failed: " + input)
    return ("","","","")
# split_url_path

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

def to_updateprogress(mytext):
    """ append to progress buffer and to log.info """
    global updateProgressBuffer
    if mytext.endswith('\n'):
        log.info(mytext[:-1])
    else:
        log.info(mytext)
    if stable:
        updateProgressBuffer.append(mytext)
        Display = configui.txt_updateprogress
        #debug("to_updateprogress: buffer_lenght %d" % (updateProgressBuffer.length(),))
        lines = Display.count_lines(1, updateProgressBuffer.length(), False)
        Display.scroll(lines, 0)
        configui.winUpdateProgress.flush()
        configui.winUpdateProgress.show()

def umount_alternate(wantprogress):
    ''' unmount the other partition '''
    if os.path.exists(alternate_partition):
        if os.path.ismount(alternate_partition):
            #if wantprogress:
            #    to_updateprogress("umount %s\n" % (alternate_partition,))
            return mysystemcall(["umount", alternate_partition], wantprogress)
    if wantprogress:
        to_updateprogress("alternate partition was not mounted, ok\n")
    else:
        log.info("alternate partition was not mounted, ok")
    return True


def untar_with_progress(filename):
    cdef int  chunk_size
    cdef long total
    cdef long processed
    cdef int  percent
    cdef int  last_percent
    cdef int  mypos
    cdef int  lastpos
    
    to_updateprogress(str_unpack_started)
    chunk_size = 1024 * 64
    total = os.path.getsize(filename)
    processed = 0
    last_percent = -1
    mypos = updateProgressBuffer.length()
    lastpos = mypos+1
    try:
        proc = subprocess.Popen("gzip -d -c | tar xf -", shell=True, stdin=subprocess.PIPE)
        with open(filename, "rb") as f:
            for chunk in iter(lambda: f.read(chunk_size), b""):
                Fl.check()
                if user_hit_cancel_button:
                    proc.stdin.close()
                    proc.wait()
                    to_updateprogress(str_unpack_canceled)
                    return False
                proc.stdin.write(chunk)
                processed += len(chunk)
                percent = 100 * processed // total
                if (percent > last_percent):
                    updateProgressBuffer.replace(mypos, lastpos, "%d%% " % (percent,))
                    configui.winUpdateProgress.flush()
                    lastpos = updateProgressBuffer.length()
                    last_percent = percent
        proc.stdin.close()
        ret = proc.wait()
        if ret == 0:
            to_updateprogress(str_unpack_completed)
            return True
        else:
            err_to_updateprogress(str_unpack_failed)
            return False
    except:
        logerrorexception()
        err_to_updateprogress(str_unpack_failed)
        return False

def untar_update():
    """ expand update to alternate partition """
    if check_update(True):
        configui.btn_updateprogress_cancel.deactivate()
        to_updateprogress("preparing filesystem, please wait\n")
        ret = mkfs(str_altmount) # start with clean filesystem
        if ret:
            to_updateprogress("filesystem done.\n")
        configui.btn_updateprogress_cancel.activate()
    if check_update(ret):
        ret = mount_alternate(False) # True -> updateprogress
    if check_update(ret):
        localpath=os.getcwd()
        fn = os.path.join(localpath, updatetar_path, str_updateFilename)
        os.chdir(alternate_partition)
        ret = untar_with_progress(fn)
        os.chdir(localpath)
        debug("unpack returned %d" % (ret,))
        return ret

def update_failed():
    """ show failure, user must press cancel """
    global UpdateFailed

    UpdateFailed = True
    UpdateHalted = True
    to_updateprogress(str_update_failed)
    configui.btn_updateprogress_cancel.activate()

def update_init():
    """ read all info concerning version and alternate partition """
    get_partition()
    get_alternate_mountname()
    if issel4():
        mount_alternate(False) # False -> no updateprogress
    get_versioncounter()
    version_init()
    if issel4():
        umount_alternate(False) # False -> no updateprogress

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
    params = addresspar[consts.UPDATEURI]
    newval = show_value(params)
    ui.out_update_server.copy_label(newval)
    ui.out_update_server.value(" " + params['title'])
    #
# update_overview

def update_update_text():
    global version
    
    fn = os.path.join(cfdict[consts.UPDATEURI], update_file)
    try:
        update_text = get_http_file(fn)
    except:
        update_text = "cannot read %s\n" % (fn, )
        log.error("cannot read %s" % (fn, ))
        updateInfoBuffer.text(update_text)
        configui.btn_updateinfo_ok.deactivate()
    else:
        #debug("update_text " + update_text)
        parse_update(update_text)
        currver = get_value(configui.out_current_version)
        log.info("updateVersion: %s, current version %s" % (str_updateVersion, currver))
        if len(currver) > 0 and str_updateVersion == currver:
            log.info("Version is current, ok")
            updateInfoBuffer.text(already_current)
            configui.btn_updateinfo_ok.deactivate()
        else:
            updateInfoBuffer.text(update_text)
            configui.btn_updateinfo_ok.activate()
# update_update_text    
    
def version_init():
    try: 
        with open(versiontext_path, 'r') as f:
            for l in f.readlines():
                configui.out_current_version.value(l.strip())
                break
    except:
        configui.out_current_version.value('unknown current version')     
    try: 
        with open(altversfilename(versiontext_path), 'r') as f:
            for l in f.readlines():
                configui.out_alternate_version.value(l.strip())
                break
    except:
        configui.out_alternate_version.value('unknown alternate version')
    if current_versioncounter > alternate_versioncounter:
        configui.btn_boot_current.value(1)
        configui.btn_boot_alternate.value(0)
    else:
        configui.btn_boot_current.value(0)
        configui.btn_boot_alternate.value(1)
# version_init
    
def warn(warnmessage):
    configui.btn_warn.copy_label(warnmessage)
    configui.btn_warn.labelcolor(88)
    configui.tab_config.hide()
    configui.btn_warn.show()

def write_alternateversion():
    """ write alternate versioncount and version.txt """
    fn = altversfilename(versioncounter_path)
    with open(fn, "w")as f:
       print(current_versioncounter +1, file=f)
    fn2 = altversfilename(versiontext_path)
    with open(fn2, "w") as f2:
       print(str_updateVersion, file=f2)
    configui.out_alternate_version.value(str_updateVersion)
    configui.btn_boot_current.value(0)
    configui.btn_boot_alternate.value(1)
    log.info("write alternate version, ok")
    return True

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
            
            if True: # ADI: force http
                configui.btn_https.value(0)
                configui.btn_https.hide()
            else:
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
    if editvals[ei] is None:
        configui.input_text.value("")
    else:
        configui.input_text.value(editvals[ei])
# write_editwindow

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
            alternate_versioncounter = current_versioncounter +1
            try:
                with open(altversfilename(versioncounter_path), 'w') as f:
                    f.write(str(alternate_versioncounter))
                    log.info("alternate versioncounter updated")  
            except:
                    log.error("update alternate versioncounter failed")

 
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
              consts.UPDATEURI: {
                'title': "Update Server",
                'heads': stdheads + ["Path",],
                'concatfunction': concat_url_path,
                'options': [consts.UPDATEURI, None, None, None ],
                'keyboard': ['abc', '123', 'abc' ],
                'restart_on_change': None,
                'showfunction': concat_url_path,
                'splitfunction': split_url_path,
                'splitparams': ["scheme", ] + stdsplitparams + ["path",],
                'testfunctions': [is_valid_host, is_valid_or_empty_port, None],
                'warnings' : stdwarnings + [None, ],
                'steps': 3 },
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
    """
        init logging
        create GUI
        set callbacks
        initialise config
        initialise on-screen values
    """
    global configui
    global helpTextBuffer
    global updateInfoBuffer
    global updateProgressBuffer
    global stable

    log = logging.getLogger("zsipos.config")
    log.info ("configui_init...")
    log.info("gitdate: %x" %(gitdates["zsipos"], ))
    ui = configui = new CONFIGUI()
    ui.window.position(0,60)
    ui.window.labeltype(FL_NORMAL_LABEL)
    ui.window.callback(on_config_enter, <void*>configui)
    ui.window.callback(on_config_close, NULL)
    # back button
    ui.btn_back.callback(on_btn_back, NULL)
    ui.btn_warn.callback(on_btn_warn, NULL)
    # tab_config - braucht genormte label
    ui.group_ip.label(str_ip_config)
    ui.group_server.label(str_server)
    ui.group_experts.label(str_experts)
    ui.tab_config.callback(on_tab_group, NULL)
    ui.btn_help.callback(on_btn_help, NULL)

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
    #Group Logs
    ui.btn_logsettings.callback(on_btn_logsettings, NULL)
    ui.btn_upload_server.callback(on_btn_edit_address, <void*>consts.UPLOADSERVER)
    ui.btn_ping_upload_server.callback(on_btn_ping, <void*>consts.UPLOADSERVER)
    ui.btn_nohup.callback(on_btn_addfile, <void*>ui.btn_nohup)
    ui.btn_zsiposlog.callback(on_btn_addfile, <void*>ui.btn_zsiposlog)
    #ui.browse_archive.filter("[a-zA-Z0-9]*")
    ui.browse_archive.load(current_archive)
    ui.browse_archive.remove(1) # hide ../
    ui.browse_archive.callback(on_browser_archive_click, NULL)
    ui.btn_upload.callback(on_btn_upload, NULL)
    ui.btn_alternate_archive.callback(on_btn_alternate_archive, NULL)
    # Group Experts
    ui.btn_local_proxy.callback(on_btn_edit_address, <void*>consts.LOCPROXYADDR)
    ui.btn_ping_local_proxy.callback(on_btn_ping, <void*>consts.LOCPROXYADDR)
    ui.btn_sshd.callback(on_btn_sshd, NULL)
    ui.btn_autosshd.callback(on_btn_autosshd, NULL)
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
    bootversion_init()
    ui.btn_show_git.callback(on_btn_show_git, NULL)
    #Group Update
    update_init()
    ui.btn_boot_current.callback(on_btn_boot_version, NULL)
    ui.btn_boot_alternate.callback(on_btn_boot_version, NULL)
    ui.out_update_server.callback(on_btn_edit_address, <void*>consts.UPDATEURI)
    ui.btn_ping_update_url.callback(on_btn_ping, <void*>consts.UPDATEURI)
    ui.btn_update_info.callback(on_btn_update_info, NULL)
    # WinSave
    ui.btn_save_and_restart.callback(on_btn_save_and_restart, NULL)
    ui.btn_save_ok.callback(on_btn_save_ok, NULL)
    ui.btn_save_cancel.callback(on_btn_save_cancel, NULL)
    # WinHelp
    helpTextBuffer = new Fl_Text_Buffer()
    ui.txt_helpDisplay.buffer(helpTextBuffer)
    ui.txt_helpDisplay.wrap_mode(3, 0) # 3=WRAP_AT_BOUNDS
    ui.txt_helpDisplay.scrollbar_width(20)
    helpTextBuffer.text(help_ip_config)
    ui.btn_help_back.callback(on_btn_help_back, NULL)
    # WinEditAddress
    ui.btn_address_back.callback(on_btn_address_back, NULL)
    ui.btn_address_ok.callback(on_btn_address_ok, NULL)
    ui.btn_address_next.callback(on_btn_address_next, NULL)
    ui.btn_address_cancel.callback(on_btn_address_cancel, NULL)
    ui.btn_address_warn.callback(on_btn_address_warn, NULL)
    # Keyboard callbacks
    keyboard_init()
    if infstr:
        warn(infstr)
    # WinLogSettings
    ui.btn_logsettings_back.callback(on_btn_logsettings_back, NULL)
    # WinUpdateInfo
    updateInfoBuffer = new Fl_Text_Buffer()
    ui.txt_updateinfo.buffer(updateInfoBuffer)
    ui.txt_updateinfo.wrap_mode(3, 0) # 3=WRAP_AT_BOUNDS
    ui.txt_updateinfo.scrollbar_width(20)
    ui.btn_updateinfo_back.callback(on_btn_updateinfo_back, NULL)
    ui.btn_updateinfo_ok.callback(on_btn_updateinfo_ok, NULL)
    # WinUpdateSure
    ui.btn_updatesure_ok.callback(on_btn_updatesure_ok, NULL)
    ui.btn_updatesure_cancel.callback(on_btn_updatesure_cancel, NULL)
    # WinUpdateProgress
    updateProgressBuffer = new Fl_Text_Buffer()
    updateProgressBuffer.text("")
    ui.txt_updateprogress.buffer(updateProgressBuffer)
    ui.txt_updateprogress.wrap_mode(3, 0) # 3=WRAP_AT_BOUNDS
    ui.txt_updateprogress.scrollbar_width(20)
    ui.btn_updateprogress_cancel.callback(on_btn_updateprogress_cancel, NULL)
    #ui.btn_updateprogress_back.callback(on_btn_updateprogress_back, NULL)
    ui.btn_updateprogress_reboot.callback(on_btn_restart, <void*>'reboot')
    # WinEditHex
    ui.btn_hex_back.callback(on_btn_hex_ignore, NULL)
    ui.btn_hex_cancel.callback(on_btn_hex_cancel, NULL)
    ui.btn_hex_ok.callback(on_btn_hex_ok, NULL)
    ui.btn_hex_warn.callback(on_btn_hex_warn, NULL)
    # Keyboard callbacks
    keyboardhex_init()
    stable = True
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
        Fl_Button*          btn_logsettings
        Fl_Output*          btn_upload_server
        Fl_Button*          btn_ping_upload_server
        Fl_Check_Button*    btn_nohup
        Fl_Check_Button*    btn_zsiposlog
        Fl_File_Browser*    browse_archive
        Fl_Button*          btn_upload
        Fl_Round_Button*     btn_alternate_archive
        # LogSettings
        Fl_Double_Window*   winLogSettings
        Fl_Button*          btn_logsettings_back
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
        Fl_Check_Button*    btn_skipzrtp1
        Fl_Check_Button*    btn_sshd
        Fl_Check_Button*    btn_autosshd
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
        Fl_Output*          out_bootversion
        # Update
        Fl_Group*           group_update
        Fl_Output*          out_current_version
        Fl_Output*          out_alternate_version
        Fl_Group*           group_btn_bootversion 
        Fl_Round_Button*    btn_boot_current
        Fl_Round_Button*    btn_boot_alternate
        Fl_Button*          btn_update_info
        
        # Save
        Fl_Double_Window*   winSave
        #Fl_Group*           group_save
        Fl_Button*          btn_save_and_restart
        Fl_Button*          btn_save_ok
        Fl_Button*          btn_save_cancel
        Fl_Box*             box_restart

        # Help
        Fl_Double_Window*   winHelp
        Fl_Button*          btn_help_back
        Fl_Text_Display*    txt_helpDisplay
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
        Fl_Button*          key_space
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

        # UpdateInfo
        Fl_Double_Window*   winUpdateInfo
        Fl_Button*          btn_updateinfo_back
        Fl_Output*          out_update_server
        Fl_Button*          btn_ping_update_url
        Fl_Text_Display*    txt_updateinfo
        Fl_Button*          btn_updateinfo_ok

        # Update
        Fl_Double_Window*   winUpdateSure
        Fl_Box*             box_updatesure
        Fl_Button*          btn_updatesure_cancel
        Fl_Button*          btn_updatesure_ok

        # Update Progress
        Fl_Double_Window*   winUpdateProgress
        Fl_Text_Display*    txt_updateprogress
        #Fl_Button*          btn_updateprogress_back
        Fl_Button*          btn_updateprogress_cancel
        Fl_Button*          btn_updateprogress_reboot
        #Fl_Box*             box_updateprogress_reboot_warn

        # EditHex
        Fl_Double_Window*   winEditHex
        Fl_Button*          btn_hex_back
        Fl_Button*          btn_hex_ok
        Fl_Button*          btn_hex_cancel
        Fl_Group*           hexgroup
        Fl_Input*           input_hex
        Fl_Button*          btn_hex_warn
        
        # Keyboard hex Funktionskeys
        Fl_Group*           keyboardgroup_hex_func
        Fl_Button*          key_hex_del
        Fl_Button*          key_hex_back
        Fl_Button*          key_hex_forward

        # Keyboard hex
        Fl_Group*           keyboardgroup_hex
        Fl_Button*          key_h1
        Fl_Button*          key_h2
        Fl_Button*          key_h3
        Fl_Button*          key_h4
        Fl_Button*          key_h5
        Fl_Button*          key_h6
        Fl_Button*          key_h7
        Fl_Button*          key_h8
        Fl_Button*          key_h9
        Fl_Button*          key_h0
        Fl_Button*          key_hA
        Fl_Button*          key_hB
        Fl_Button*          key_hC
        Fl_Button*          key_hD
        Fl_Button*          key_hE
        Fl_Button*          key_hF

        CONFIGUI() nogil
