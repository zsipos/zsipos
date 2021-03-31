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
# config_server.pxi
#
# Author: Esther Bergter
#
# Version 1.0

server_initialized = False

# Group Server
def group_server_init():
    global server_initialized

    ui = configui
    ui.btn_help.show()

    if server_initialized:
        return

    ui.btn_sipproxy.callback(on_btn_sipproxy, NULL)
    ui.btn_sipproxy.value(" SIP Proxy")
    ui.btn_sipproxy.copy_label(disp_simple(consts.SIPPROXY))
    ui.btn_ping_sipproxy.callback(on_btn_ping_sipproxy, NULL)

    ui.btn_icestorageurl.callback(on_btn_icestorageurl, NULL)
    ui.btn_icestorageurl.value(" ICE Storage URL")
    ui.btn_icestorageurl.copy_label(disp_simple(consts.ICESTORAGEURL))
    ui.btn_ping_icestorageurl.callback(on_btn_ping_icestorageurl, NULL)

    ui.btn_stunserver.callback(on_btn_stunserver, NULL)
    ui.btn_stunserver.value(" STUN Server")
    ui.btn_stunserver.copy_label(disp_simple(consts.STUNSERVER))
    ui.btn_ping_stunserver.callback(on_btn_ping_stunserver, NULL)

    ui.btn_turnserver.callback(on_btn_turnserver, NULL)
    ui.btn_turnserver.value(" TURN Server")
    ui.btn_turnserver.copy_label(disp_turn(consts.TURNSERVER, consts.TURNUSER, consts.TURNPASSWORD))
    ui.btn_ping_turnserver.callback(on_btn_ping_turnserver, NULL)

    ui.btn_ntpserver.callback(on_btn_ntpserver, NULL)
    ui.btn_ntpserver.value(" NTP Server")
    ui.btn_ntpserver.copy_label(disp_simple(consts.NTPSERVER))
    ui.btn_ping_ntpserver.callback(on_btn_ping_ntpserver, NULL)

    server_initialized = True

cdef void on_btn_sipproxy(Fl_Widget *widget, void *data) with gil:
    global my_edit
    btn = configui.btn_sipproxy
    class Edit_Split(EditAddress_split):
        def __init__(self, var, ty):
            nonlocal btn
            self.var = var
            super().__init__(
            title=get_value(btn).strip(),
            options=[var],
            type=ty)

        def OkPressed(self):
            nonlocal btn
            debug("OkPressed")
            newval = disp_simple(self.var)
            btn.copy_label(newval)

        def Cancel(self):
            debug("Cancel")

    my_edit = Edit_Split(consts.SIPPROXY, 'hostp')

cdef void on_btn_ping_sipproxy(Fl_Widget* widget, void *data) with gil:
    ping_hostp(consts.SIPPROXY)

cdef void on_btn_icestorageurl(Fl_Widget *widget, void *data) with gil:
    global my_edit
    btn = configui.btn_icestorageurl
    class Edit_Split(EditAddress_split):
        def __init__(self, var, ty):
            nonlocal btn
            self.var = var
            super().__init__(
            title=get_value(btn).strip(),
            options=[var],
            type=ty)

        def OkPressed(self):
            nonlocal btn
            debug("OkPressed")
            newval = disp_simple(self.var)
            btn.copy_label(newval)

        def Cancel(self):
            debug("Cancel")

    my_edit = Edit_Split(consts.ICESTORAGEURL, 'url')

cdef void on_btn_ping_icestorageurl(Fl_Widget* widget, void *data) with gil:
    ping_url(consts.ICESTORAGEURL)

cdef void on_btn_stunserver(Fl_Widget *widget, void *data) with gil:
    global my_edit
    btn = configui.btn_stunserver
    class Edit_Split(EditAddress_split):
        def __init__(self, var, ty):
            nonlocal btn
            self.var = var
            super().__init__(
            title=get_value(btn).strip(),
            options=[var],
            type=ty)

        def OkPressed(self):
            nonlocal btn
            debug("OkPressed")
            newval = disp_simple(self.var)
            btn.copy_label(newval)

        def Cancel(self):
            debug("Cancel")

    my_edit = Edit_Split(consts.STUNSERVER, 'hostp')

cdef void on_btn_ping_stunserver(Fl_Widget* widget, void *data) with gil:
    ping_hostp(consts.STUNSERVER)

cdef void on_btn_turnserver(Fl_Widget *widget, void *data) with gil:
    global my_edit
    btn = configui.btn_turnserver
    class Edit_Split(EditAddress_split):
        def __init__(self, var, ty, **kwargs):
            debug(f'Edit_Split: {kwargs}')
            nonlocal btn
            self.hostvar = var
            self.uservar = kwargs['user']
            self.pwvar = kwargs['password']
            super().__init__(
            title=get_value(btn).strip(),
            options=[self.hostvar, self.uservar, self.pwvar],
            type=ty)

        def OkPressed(self):
            nonlocal btn
            debug("OkPressed")
            newval = disp_turn(self.hostvar, self.uservar, self.pwvar)
            btn.copy_label(newval)

        def Cancel(self):
            debug("Cancel")

    my_edit = Edit_Split(consts.TURNSERVER, 'turn', user=consts.TURNUSER, password=consts.TURNPASSWORD)

cdef void on_btn_ping_turnserver(Fl_Widget* widget, void *data) with gil:
    ping_hostp(consts.TURNSERVER)

cdef void on_btn_ntpserver(Fl_Widget *widget, void *data) with gil:
    global my_edit
    btn = configui.btn_ntpserver
    class Edit_Simple(EditAddress):
        def __init__(self, var, ty):
            nonlocal btn
            self.var = var
            super().__init__(
            title=get_value(btn).strip(),
            options=[var],
            type=ty)

        def OkPressed(self):
            nonlocal btn
            debug("OkPressed")
            newval = disp_simple(self.var)
            btn.copy_label(newval)

        def Cancel(self):
            debug("Cancel")

    my_edit = Edit_Simple(consts.NTPSERVER, 'host')

cdef void on_btn_ping_ntpserver(Fl_Widget* widget, void *data) with gil:
    ping_simple(consts.NTPSERVER)

