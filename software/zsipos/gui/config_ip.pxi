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
# config_ip.pxi
#
# Author: Esther Bergter
#
# Version 1.0

ip_initialized = False

#Group IP
def group_ip_init():
    global ip_initialized

    ui = configui
    ui.btn_help.show()

    if ip_initialized:
        return

    if consts.EXTUSEDHCP in cfdict and cfdict[consts.EXTUSEDHCP]:
        use_dhcp(True)
    else:
        use_dhcp(False)
    ui.btn_dhcp.callback(on_btn_dhcp, NULL)
    ui.btn_static_ip.callback(on_btn_dhcp, NULL)
    ui.btn_auto_dns.callback(on_btn_dns, NULL)
    ui.btn_static_dns.callback(on_btn_dns, NULL)

    ui.btn_extphoneaddr.callback(on_btn_extphoneaddr, NULL)
    ui.btn_extphoneaddr.value(" My IP Address")
    ui.btn_extphoneaddr.copy_label(disp_host_port(consts.EXTPHONEADDR, consts.EXTPHONEPORT))
    #no ping

    ui.btn_extnetmask.callback(on_btn_extnetmask, NULL)
    ui.btn_extnetmask.value(" Subnet Mask")
    ui.btn_extnetmask.copy_label(disp_simple(consts.EXTNETMASK))
    #no ping

    ui.btn_extgateway.callback(on_btn_extgateway, NULL)
    ui.btn_extgateway.value(" Gateway")
    ui.btn_extgateway.copy_label(disp_simple(consts.EXTGATEWAY))
    ui.btn_ping_extgateway.callback(on_btn_ping_extgateway, NULL)

    ui.btn_dnsserver.callback(on_btn_dnsserver, NULL)
    ui.btn_dnsserver.value(" DNS Server")
    ui.btn_dnsserver.copy_label(disp_simple(consts.DNSSERVER))
    ui.btn_ping_dnsserver.callback(on_btn_ping_dnsserver, NULL)

    ip_initialized = True

cdef void on_btn_dhcp(Fl_Widget* widget, void *data) with gil:
    if get_value(configui.btn_dhcp) == 1:
        use_dhcp(True)
    else:
        use_dhcp(False)

cdef void on_btn_dns(Fl_Widget* widget, void *data) with gil:
    if get_value(configui.btn_auto_dns) == 1:
        cfdict['AutoDns'] = True
        configui.group_dns.deactivate()
    else:
        cfdict['AutoDns'] = False
        configui.group_dns.activate()

cdef void on_btn_dnsserver(Fl_Widget *widget, void *data) with gil:
    global my_edit
    btn = configui.btn_dnsserver
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

    my_edit = Edit_Simple(consts.DNSSERVER, 'ip')

cdef void on_btn_ping_dnsserver(Fl_Widget* widget, void *data) with gil:
    ping_simple(consts.DNSSERVER)

cdef void on_btn_extgateway(Fl_Widget *widget, void *data) with gil:
    global my_edit
    btn = configui.btn_extgateway
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

    my_edit = Edit_Simple(consts.EXTGATEWAY, 'ip')

cdef void on_btn_ping_extgateway(Fl_Widget* widget, void *data) with gil:
    ping_simple(consts.EXTGATEWAY)


cdef void on_btn_extnetmask(Fl_Widget *widget, void *data) with gil:
    global my_edit
    btn = configui.btn_extnetmask
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

    my_edit = Edit_Simple(consts.EXTNETMASK, 'netmask')

cdef void on_btn_extphoneaddr(Fl_Widget *widget, void *data) with gil:
    global my_edit
    btn = configui.btn_extphoneaddr
    class Edit_host_port(EditAddress_host_port):
        def __init__(self, host, port):
            nonlocal btn
            self.host = host
            self.port = port
            super().__init__(
            title=get_value(btn).strip(),
            options=[host, port],
            type='ip-port')

        def OkPressed(self):
            nonlocal btn
            debug("OkPressed")
            newval = disp_host_port(self.host, self.port)
            btn.copy_label(newval)

        def Cancel(self):
            debug("Cancel")

    my_edit = Edit_host_port(consts.EXTPHONEADDR, consts.EXTPHONEPORT)

def static_dns(on):
    """ switch from auto dns to static dns and back """
    if on:
        cfdict['AutoDns'] = False
        configui.btn_static_dns.value(1)
        configui.btn_auto_dns.value(0)
        configui.group_dns.activate()
    else:
        cfdict['AutoDns'] = True
        configui.btn_static_dns.value(0)
        configui.btn_auto_dns.value(1)
        configui.group_dns.deactivate()

def use_dhcp(on):
    """ switch from dhcp to static ip and back """
    if on:                                  # dhcp
        cfdict[consts.EXTUSEDHCP] = True
        configui.btn_dhcp.value(1)
        configui.group_static_ip.deactivate()
        configui.group_btn_dns.activate()
        #debug("on_btn_dhcp btn_dns_server")
        if consts.DNSSERVER in cfdict and len(cfdict[consts.DNSSERVER]):
            static_dns(True)
        else:
            static_dns(False)
    else:                                    # kein dhcp
        cfdict[consts.EXTUSEDHCP] = False
        configui.btn_static_ip.value(1)
        configui.group_static_ip.activate()
        configui.group_btn_dns.deactivate()
        static_dns(True)

