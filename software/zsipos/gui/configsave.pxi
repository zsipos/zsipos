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
# configsave.pxi
#
# Author: Esther Bergter
#
# Version 1.0

save_initialized = False

def save_init():
    """ connect callbacks """
    global save_initialized

    ui = configui
    ui.btn_save_and_restart.callback(on_btn_save_and_restart, NULL)
    ui.btn_save_ok.callback(on_btn_save_ok, NULL)
    ui.btn_save_cancel.callback(on_btn_save_cancel, NULL)
    save_initialized = True

cdef void on_btn_save_and_restart(Fl_Widget* widget, void *data) with gil:
    """ save cfg and restart corresponding to the label """
    do_save_cfg()
    configui.winSave.hide()
    # label e.g. 'Save and Restart'
    lbl = get_label(configui.btn_save_and_restart).split(' ')[-1].lower()
    if lbl == 'update':
        show_sure('Are you sure to update now?', 'Update')
    else:
        do_restart(lbl)

cdef void on_btn_save_ok(Fl_Widget* widget, void *data) with gil:
    #debug("on_btn_save")
    do_save_cfg()
    configui.winSave.hide()

cdef void on_btn_save_cancel(Fl_Widget* widget, void *data) with gil:
    configui.winSave.hide()


# python
def show_save(info, restart_type):
    """ show WinSave """
    if not save_initialized:
        save_init()
    log.info(info)
    if restart_type is None:
        configui.box_restart.copy_label(info)
        configui.btn_save_and_restart.hide()
    else:
        configui.box_restart.copy_label(info)
        label = "Save and %s" % (restart_type.capitalize(),)
        configui.btn_save_and_restart.copy_label(label)
        configui.btn_save_and_restart.show()
    configui.winSave.show()
