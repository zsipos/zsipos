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
# config_experts.pxi
#
# Author: Esther Bergter
#
# Version 1.0

experts_initialized = False

#Group Experts
def group_experts_init():
    global experts_initialized

    ui = configui
    ui.btn_help.show()

    if experts_initialized:
        return

    #localproxy
    ui.btn_localproxyaddr.callback(on_btn_localproxyaddr, NULL)
    ui.btn_localproxyaddr.value(" Local Proxy")
    ui.btn_localproxyaddr.copy_label(disp_simple(consts.LOCPROXYADDR))
    ui.btn_ping_localproxyaddr.callback(on_btn_ping_localproxyaddr, NULL)
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
    if is_testversion():
        if os.path.exists(sshd_initd):
            ui.btn_autosshd.value(1)
        else:
            ui.btn_autosshd.value(0)
    else:
        """ no sshd autostart """
        if issel4() and os.path.exists(sshd_initd):
            os.remove(sshd_initd)
            log.info("init: sshd autostart removed")
        ui.btn_autosshd.value(0)
        ui.btn_autosshd.hide()

    ui.btn_sshd.callback(on_btn_sshd, NULL)
    if is_testversion():
        ui.btn_autosshd.callback(on_btn_autosshd, NULL)
    # skipzrtp1
    ui.btn_skipzrtp1.value(cfdict[consts.SKIPZRTP1])
    ui.btn_skipzrtp1.callback(on_btn_skipzrtp1, <void*>consts.SKIPZRTP1)
    experts_initialized = True

cdef void on_btn_localproxyaddr(Fl_Widget *widget, void *data) with gil:
    global my_edit
    btn = configui.btn_localproxyaddr
    class Edit_host_port(EditAddress_host_port):
        def __init__(self, host, port):
            nonlocal btn
            self.host = host
            self.port = port
            super().__init__(
            title=get_value(btn).strip(),
            options=[host, port],
            type='host-port')

        def OkPressed(self):
            nonlocal btn
            debug("OkPressed")
            newval = disp_host_port(self.host, self.port)
            btn.copy_label(newval)

        def Cancel(self):
            debug("Cancel")

    my_edit = Edit_host_port(consts.LOCPROXYADDR, consts.LOCPROXYPORT)

cdef void on_btn_ping_localproxyaddr(Fl_Widget* widget, void *data) with gil:
    ping_simple(consts.LOCPROXYADDR)

cdef void on_btn_autosshd(Fl_Widget* widget, void *data) with gil:
    #debug(os.uname())
    if get_value(configui.btn_autosshd) == 1:
        if issel4():
            if not os.path.exists(sshd_initd):
                os.symlink('/etc/init.d/sshd', sshd_initd)
        else:
            what = 'autosshd requested on'
            info(f"TestModus {what}")
            log.info(what)
    else:
        if issel4():
            if os.path.exists(sshd_initd):
                os.remove(sshd_initd)
        else:
            what = 'autosshd requested off'
            info(f"TestModus {what}")
            log.info(what)

cdef void on_btn_sshd(Fl_Widget* widget, void *data) with gil:
    #debug(os.uname())
    if get_value(configui.btn_sshd) == 0:
        if issel4():
            os.system('/etc/init.d/sshd stop')
        else:
            what = 'sshd requested stop'
            info(f"TestModus {what}")
            log.info(what)
    else:
        if issel4():
            if not os.path.isfile('/etc/ssh/ssh_host_rsa_key'):
                info(str_sshd_first_start)
            os.system('/etc/init.d/sshd start')
        else:
            what = 'sshd requested start'
            info(f"TestModus {what}")
            log.info(what)

cdef void on_btn_skipzrtp1(Fl_Widget* widget, void *data) with gil:
    myname = <str>data
    mywidget = <Fl_Check_Button*>widget
    cfdict[myname] = to_bool(get_value(mywidget))
    debug(f'on_btn_skipzrtp1: {myname} = {cfdict[myname]}')
