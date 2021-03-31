# SPDX-FileCopyrightText: 2021 Esther Bergter <esther.bergter@vipcomag.de>
#
# SPDX-License-Identifier: GPL-3.0-or-later

"""
Copyright (C) 2021 Esther Bergter

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
# config_update.pxi
#
# Author: Esther Bergter
#
# Version 1.0

include 'confighexkeyboard.pxi'
include 'config_updatesubwindows.pxi'

current_versioncounter = 0
alternate_versioncounter = 0

hexdigest_matches = False
user_hit_cancel_button = False
UpdateFailed = False
UpdateHalted = False
update_binary = None

update_initialized = False

#Group Update
def group_update_init():
    global update_initialized

    ui = configui
    ui.btn_help.hide()

    if update_initialized:
        return


    update_init()
    ui.btn_boot_current.callback(on_btn_boot_version, NULL)
    ui.btn_boot_alternate.callback(on_btn_boot_version, NULL)

    ui.btn_updateuri.callback(on_btn_updateuri, NULL)
    ui.btn_updateuri.value(" Update Server")
    ui.btn_updateuri.copy_label(disp_simple(consts.UPDATEURI))
    ui.btn_ping_updateuri.callback(on_btn_ping_updateuri, NULL)

    ui.btn_update_info.callback(on_btn_update_info, NULL)

    # Subwindows
    #subwindows_init()
    update_initialized = True


# callbacks
cdef void on_btn_boot_version(Fl_Widget* widget, void *data) with gil:

    if get_value(configui.btn_boot_current) == 1:   # current
        cfdict['BOOT_CURRENT'] = True
    else:                                    # alternate
        cfdict['BOOT_CURRENT'] = False

cdef void on_btn_update_info(Fl_Widget* widget, void *data) with gil:
    update_update_text()
    #configui.winUpdateInfo.show()

cdef void on_btn_updateuri(Fl_Widget *widget, void *data) with gil:
    global my_edit
    btn = configui.btn_updateuri
    class Edit_Split(EditAddress_split):
        def __init__(self, var, ty):
            nonlocal btn
            self.var = var
            super().__init__(
            title = get_value(btn).strip(),
            options = [var],
            type = ty)

        def OkPressed(self):
            nonlocal btn
            debug("OkPressed")
            newval = disp_simple(self.var)
            btn.copy_label(newval)

        def Cancel(self):
            debug("Cancel")
    my_edit = Edit_Split(consts.UPDATEURI, 'url-path')

cdef void on_btn_ping_updateuri(Fl_Widget* widget, void *data) with gil:
    ping_url_path(consts.UPDATEURI)

# python
def altversfilename(source):
    """ magic absolute path """
    return (os.path.join(alternate_partition, source[1 if source.startswith('/') else 0 :]))

def get_http_file_binary(url):
    """ read http file and return content """
    response = requests.get(url)
    return response.content

def get_versioncounter():
    """ read current and alternate versioncounter """
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
    if checkmount_alternate(True):
        try:
            with open(altversfilename(versioncounter_path), 'r') as f:
                for l in f.readlines():
                    str_counter = l.strip()
                    break
                alternate_versioncounter = int(str_counter)
        except:
            log.error("cannot read %s" % (altversfilename(versioncounter_path), ))
            alternate_versioncounter = 0
    else:
        alternate_versioncounter = 0
    log.info("current versioncounter: %d, alternate versioncounter %d" %(current_versioncounter, alternate_versioncounter))

    if current_versioncounter > alternate_versioncounter:
        configui.btn_boot_current.value(1)
        configui.btn_boot_alternate.value(0)
    else:
        configui.btn_boot_current.value(0)
        configui.btn_boot_alternate.value(1)
# g_et_versioncounter

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

def update_init():
    """ read all info concerning version and alternate partition """
    checkmount_alternate(True)  # mount, accept failure
    get_versioncounter()
    version_init()
    # Boot Version
    if current_versioncounter > alternate_versioncounter:
        olddict['BOOT_CURRENT'] = True
        cfdict['BOOT_CURRENT'] = True
    else:
        olddict['BOOT_CURRENT'] = False
        cfdict['BOOT_CURRENT'] = False
    checkmount_alternate(False) # umount, accept failure

def update_update_text():
    global version
    global update_binary

    fn = os.path.join(cfdict[consts.UPDATEURI], update_file)
    try:
        update_binary = get_http_file_binary(fn)
    except:
        logerrorexception('help')
        update_text = "cannot read %s\n" % (fn, )
        append_help(update_text)
    else:
        update_text = update_binary.decode('utf-8')
        #debug("update_text " + update_text)
        parse_update(update_text)
        currver = get_value(configui.out_current_version)
        log.info("updateVersion: %s, current version %s" % (str_updateVersion, currver))
        if len(currver) > 0 and str_updateVersion == currver and not is_testversion():
            show_help('Update Info', "Version is already current")
        else:
            show_updateinfo(update_text)
# u_pdate_update_text

def version_init():
    try:
        with open(versiontext_path, 'r') as f:
            for l in f.readlines():
                configui.out_current_version.value(l.strip())
                break
    except:
        configui.out_current_version.value('unknown current version')
    if checkmount_alternate(True):
        try:
            with open(altversfilename(versiontext_path), 'r') as f:
                for l in f.readlines():
                    configui.out_alternate_version.value(l.strip())
                    break
        except:
            configui.out_alternate_version.value('unknown alternate version')
    else:
        configui.out_alternate_version.value('no alternate version')
# v_ersion_init

