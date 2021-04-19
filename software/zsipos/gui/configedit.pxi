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
# configedit.pxi
#
# Author: Esther Bergter
#
# Version 1.0


# strings
stdHeadHost = "Full DNS name (FQDN) or IP Address"
stdWarnHost = "Not a valid Host Name"
stdHeadIP   = "IP Address"
stdWarnIP   = "Not a valid IP Address"
stdHeadPort = "Port"
stdWarnPort =  "Not a valid Port"

stdheads = [stdHeadHost, stdHeadPort]
stdsplitfunction = split_host_port
stdsplitparams = ["FQDN or IP", "Port"]
stdkeyboard = ['abc', '123']
stdtests = [is_valid_host, is_valid_port]
stdwarnings = [stdWarnHost, stdWarnPort]

# the Window where editing is done
class EditWindow(object):

    def __init__(self, parent, **kwargs):
        debug(f'EditWindow: {kwargs}')
        self.parent = parent
        self.value = kwargs['value']
        self.title = kwargs['title']
        self.head = kwargs['head']
        self.keyboard = kwargs['keyboard']
        self.last = kwargs['last']
        self.show_http = kwargs['show_http']
        self.https = kwargs['https']
        self.testfunction =kwargs['testfunction']
        self.warning = kwargs['warning']

        configui.btn_address_ok.callback(on_btn_address_ok, <void *>self)
        configui.btn_address_next.callback(on_btn_address_next, <void *>self)
        configui.btn_address_back.callback(on_btn_address_back, <void *>self)
        configui.btn_address_cancel.callback(on_btn_address_cancel, <void *>self)
        configui.btn_address_warn.callback(on_btn_address_warn, NULL)

    def save(self):
        self.value = get_value(configui.input_text)
        if self.testfunction is not None:
            if (self.testfunction == is_valid_or_empty_port 
                and self.testfunction(self.value)):
                pass
            elif len(self.value) and self.testfunction(self.value):
                pass
            else:
                configui.btn_address_warn.copy_label(self.warning)
                configui.btn_address_warn.show()
                configui.input_text.take_focus()
                return False
        if self.show_http:
            if get_value(configui.btn_https) == 1:
                self.https = 'https'
            else:
                self.https = 'http'
        return True

    def select_button(self):
        """ set ok button or next button """
        if self.last:
            # just one window
            configui.btn_address_ok.show()
            configui.btn_address_next.hide()
        else:
            configui.btn_address_ok.hide()
            configui.btn_address_next.show()

    def show(self):
        global key_state

        self.select_button() # next or ok button
        configui.addressgroup.copy_label(self.title)
        configui.input_text.copy_label(self.head)
        if self.value is None:
            configui.input_text.value("")
        else:
            configui.input_text.value(self.value)
        debug(f'EditWindow show self.https = {self.https}')
        if self.https == 'https':
            configui.btn_https.value(1)
        else:
            configui.btn_https.value(0)
        if self.show_http:
            configui.btn_https.show()
        else:
            configui.btn_https.hide()
        key_state = self.keyboard
        keyboard_show(key_state)
        # warning off
        configui.btn_address_warn.hide()
        # now show it
        configui.winEditAddress.show()

# An address can be composed of several parts
# This is the base class, suitable for simple addresses
class EditAddress(object):

    def __init__(self, **kwargs):
        debug(f'EditAddress: {kwargs}')
        if 'title' in kwargs:
            self.title = kwargs['title']
        if 'options' in kwargs:
            self.options = kwargs['options']
            debug(f'options = {self.options}')
        self.type = kwargs['type']
        self.show_http = False
        self.https = None
        if 'forcehttp' in kwargs:
            self.forcehttp = kwargs['forcehttp']
        else:
            self.forcehttp = None
        debug(f'EditAddress: forcehttp {self.forcehttp}')
        self.init()
        self.show()

    def Cancel(self):
        "Cancel callback - caller must implement it "
        raise Exception("EditAddress::Cancel is virtual")

    def OkPressed(self):
        "ok callback - caller must implement it "
        raise Exception("EditAddress::OkPressed is virtual")

    def close(self):
        debug("EditAddress::close")
        configui.tab_config.take_focus()
        configui.winEditAddress.hide()

    def back_pressed(self):
        debug("EditAddress::back_pressed")
        if self.estep > 0:
            self.estep -= 1
            self.show()
        else:
            self.cancel_pressed()

    def ok_pressed(self):
        debug("EditAddress::ok_pressed")
        self.save()
        self.close()
        self.OkPressed()

    def next_pressed(self):
        debug("EditAddress::next_pressed")
        self.estep += 1
        self.show()

    def cancel_pressed(self):
        self.close()
        self.Cancel()

    def cache(self, edit):
        " remember edit value "
        self.editvals[self.estep] = edit.value
        debug(f"cache new val {self.editvals[self.estep]}")
        if edit.https is not None:
            self.https = edit.https
            debug(f"cache https {self.https}")

    def debug_editval(self, string):
        if not debuginfo: return
        debug(string)
        debug(self.editvals)

    def init(self):
        """ init from type """

        type = self.type
        self.estep = 0 # first step
        self.editvals = []
        self.heads = [None]
        self.keyboard = ['abc']
        self.testfunctions = [None]
        self.warnings = [None]
        self.steps = 1

        if type == 'host':
            self.heads = [stdHeadHost]
            self.testfunctions = [is_valid_host]
            self.warnings = [stdWarnHost]
        elif type == 'ip':
            self.heads = [stdHeadIP]
            self.keyboard = ['123']
            self.testfunctions = [is_valid_ip]
            self.warnings = [stdWarnIP]
        elif type == 'netmask':
            self.heads = ["IP Mask"]
            self.keyboard = ['123']
            self.testfunctions = [is_valid_mask]
            self.warnings = ["Not a valid Mask"]
        elif type == 'uploadid':
            self.heads = ['Upload Id']
        else:
            raise Exception("unknown type {}".format(type))
        # read start value
        self.read_simple(self.options[0])

    def is_last_step(self):
        " True if estep is last step "
        debug("is_last_step: steps = {} estep = {}\n".format(self.steps, self.estep))
        if self.estep+1 < self.steps:
            return False
        else:
            return True

    def read_simple(self, cfvar):
        """ append cfdict[cfvar] to editvals """
        if cfvar in cfdict:
            self.editvals.append(cfdict[cfvar])
        else:
            self.editvals.append('')

    def save(self):
        """ save editvals to cfdict """
        self.save_simple()

    def save_simple(self):
        for i in range(self.steps):
            cfdict[self.options[i]] = self.editvals[i]

    def show(self):
        """ show Edit Window """
        params = {
            'value' : self.editvals[self.estep], # show last edited
            'title' : self.title,
            'head' : self.heads[self.estep],
            'keyboard' : self.keyboard[self.estep],
            'last' : self.is_last_step(),
            # show_http on first page only
            'show_http' : self.estep == 0 and self.show_http,
            'https' : self.https,
            'testfunction' : self.testfunctions[self.estep],
            'warning' : self.warnings[self.estep],
        }
        debug(f"EditAddress show: {params}")
        class MyEditWindow(EditWindow):
            def __init__(self, parent):
                super().__init__(parent, **params)

        self.EditWindow = MyEditWindow(self)
        self.EditWindow.show()

# host and port have separate configs
class EditAddress_host_port(EditAddress):
    def init(self):
        """ init from type """

        type = self.type
        self.estep = 0 # first step
        self.editvals = []
        self.heads = []
        self.testfunctions = []
        self.warnings = []

        self.steps = 2
        if type == 'host-port':
            self.heads = stdheads
            self.keyboard = stdkeyboard
            self.testfunctions = stdtests
            self.warnings = stdwarnings
        elif type == 'ip-port':
            self.heads = [stdHeadIP, stdHeadPort]
            self.keyboard = ['123', '123']
            self.testfunctions = [is_valid_ip, is_valid_port]
            self.warnings = [stdWarnIP, stdWarnPort]
        else:
            raise Exception("unknown type {}".format(type))
        self.read_simple(self.options[0])
        self.read_simple(self.options[1])
        self.debug_editval("EditAddress_host_port init")

# config needs splitting into e.g. http host port
class EditAddress_split(EditAddress):
    def init(self):
        """ init from type """

        type = self.type
        self.estep = 0 # first step
        self.editvals = []
        self.heads = []
        self.testfunctions = []
        self.warnings = []

        if type == 'hostp':
            self.steps = 2
            self.heads = stdheads
            self.keyboard = stdkeyboard
            self.testfunctions = stdtests
            self.warnings = stdwarnings
            self.read_hostp(self.options[0])
        elif type == 'url':
            # port is mandatory, part of value
            self.steps = 2
            self.heads = stdheads
            self.keyboard = stdkeyboard
            self.testfunctions = stdtests
            self.warnings = stdwarnings
            self.show_http = True
            self.read_url(self.options[0])
        elif type == 'url-path':
            # port is optional, part of value
            self.steps = 3
            self.heads = [stdHeadHost, "Port(optional)", "Path"]
            self.keyboard = ['abc', '123', 'abc']
            debug(f'EditAddress_split: forcehttp {self.forcehttp}')
            if self.forcehttp is None:
                self.show_http = True
            else:
                self.show_http = False
                self.https = self.forcehttp
            self.testfunctions = [is_valid_host, is_valid_or_empty_port, None]
            self.warnings = stdwarnings + [None]
            self.read_url_path(self.options[0])
        elif type == 'turn':
            self.steps = 4
            self.heads = stdheads + ["User", "Password"]
            self.keyboard = ['abc', '123', 'abc', 'abc']
            self.testfunctions = stdtests + [None, None]
            self.warnings = stdwarnings + [None, None]
            self.read_hostp(self.options[0])
            if self.options[1] in cfdict: # UploadId
                self.editvals.append(cfdict[self.options[1]])
            else:
                self.editvals.append('')
            if self.options[2] in cfdict: # UploadId
                self.editvals.append(cfdict[self.options[2]])
            else:
                self.editvals.append('')
        elif type == 'upload':
            # port is optional, part of value
            self.steps = 4
            self.heads = [stdHeadHost, "Port(optional)", "Path", "UploadId"]
            self.keyboard = ['abc', '123', 'abc', 'abc']
            debug(f'EditAddress_split: forcehttp {self.forcehttp}')
            if self.forcehttp is None:
                self.show_http = True
            else:
                self.show_http = False
                self.https = self.forcehttp
            self.testfunctions = [is_valid_host, is_valid_or_empty_port, None, None]
            self.warnings = stdwarnings + [None, None]
            self.read_url_path(self.options[0])
            if self.options[1] in cfdict: # UploadId
                self.editvals.append(cfdict[self.options[1]])
            else:
                self.editvals.append('')
        else:
            raise Exception("unknown type {}".format(type))
        self.debug_editval("EditAddress_split init")

    def read_hostp(self, cfvar):
        """ append cfdict[cfvar] to editvals """
        if cfvar in cfdict:
            (host, port) = split_host_port(cfdict[cfvar])
            self.editvals.append(host)
            self.editvals.append(port)
        else:
            self.editvals.append('')
            self.editvals.append('')

    def read_url(self, cfvar):
        """ append cfdict[cfvar] to editvals """
        if cfvar in cfdict:
            (https, host, port) = split_url(cfdict[cfvar])
            self.https = https
            self.editvals.append(host)
            self.editvals.append(port)
        else:
            self.https = 'https'
            self.editvals.append('')
            self.editvals.append('')

    def read_url_path(self, cfvar):
        """ append cfdict[cfvar] to editvals """
        if cfvar in cfdict:
            (https, host, port, path) = split_url_path(cfdict[cfvar])
            self.https = https
            self.editvals.append(host)
            self.editvals.append(port)
            self.editvals.append(path)
        else:
            self.https = 'https'
            self.editvals.append('')
            self.editvals.append('')
            self.editvals.append('')

    def save(self):
        """ save editvals to cfdict """
        if self.type == 'hostp':
            cfdict[self.options[0]] = concat_host_port(self.editvals[0], self.editvals[1])
        elif self.type == 'url':
            cfdict[self.options[0]] = concat_url(self.https, self.editvals[0], self.editvals[1])
        elif self.type == 'url-path':
            cfdict[self.options[0]] = concat_url_path(self.https, self.editvals[0], self.editvals[1], self.editvals[2])
        elif self.type == 'turn':
            cfdict[self.options[0]] = concat_host_port(self.editvals[0], self.editvals[1])
            cfdict[self.options[1]] = self.editvals[2]
            cfdict[self.options[2]] = self.editvals[3]
        elif self.type == 'upload':
            cfdict[self.options[0]] = concat_url_path(self.https, self.editvals[0], self.editvals[1], self.editvals[2])
            cfdict[self.options[1]] = self.editvals[3]
        else:
            raise Exception("unknown type {}".format(self.type))

################################################
# WinEditAddress
#cdef extern from *:
#    cdef int Py_REFCNT(void*) nogil

cdef void on_btn_address_back(Fl_Widget* widget, void *cfdata) with gil:
    """show previous window"""
    debug('on_btn_address_back')
    #print(Py_REFCNT(cfdata))
    edit = <object>cfdata
    edit.parent.back_pressed()
# on_btn_address_back

cdef void on_btn_address_ok(Fl_Widget* widget, void *cfdata) with gil:
    """ last window, save """
    debug('on_btn_address_ok')
    # restore btn_address_cancel
    configui.btn_address_cancel.show()
    #print(Py_REFCNT(cfdata))
    edit = <object>cfdata
    if edit.save():
        edit.parent.cache(edit)
        edit.parent.ok_pressed()
# on_btn_address_ok

cdef void on_btn_address_next(Fl_Widget* widget, void *cfdata) with gil:
    """ save value and show next window """
    debug('on_btn_address_next')
    # restore btn_address_back
    configui.btn_address_back.show()
    #print(Py_REFCNT(cfdata))
    edit = <object>cfdata
    if edit.save():
        edit.parent.cache(edit)
        edit.parent.next_pressed()
# on_btn_address_next

cdef void on_btn_address_cancel(Fl_Widget* widget, void *cfdata) with gil:
    debug('on_btn_address_cancel')
    #print(Py_REFCNT(cfdata))
    edit = <object>cfdata
    edit.parent.cancel_pressed()

cdef void on_btn_address_warn(Fl_Widget* widget, void *data) with gil:
    configui.btn_address_warn.hide()
