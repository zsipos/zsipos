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
# configsure.pxi
#
# Author: Esther Bergter
#
# Version 1.0

sure_initialized = False

def sure_init():
    """ connect callbacks """
    global sure_initialized

    ui = configui
    ui.btn_sure_ok.callback(on_btn_sure_ok, NULL)
    ui.btn_sure_cancel.callback(on_btn_sure_cancel, NULL)
    sure_initialized = True

cdef void on_btn_sure_ok(Fl_Widget* widget, void *data) with gil:
    """ cancel or continue corresponding to the label """
    configui.winSure.hide()
    lbl = get_label(configui.btn_sure_ok).lower()
    if lbl == 'update':
        do_update1()
    elif lbl == 'calibrate':
        do_calibrate()
    elif lbl == 'factory reset':
        do_factory_reset()
    elif lbl == 'zid reset':
        do_zid_reset()
    else:
        # label e.g. 'Restart'
        do_restart(lbl)

cdef void on_btn_sure_cancel(Fl_Widget* widget, void *data) with gil:
    configui.winSure.hide()

# python
def show_sure(question, label):
    """ show winSure """
    if not sure_initialized:
        sure_init()
    log.info(question)
    configui.box_sure.copy_label(question)
    configui.btn_sure_ok.copy_label(label)
    configui.winSure.show()
