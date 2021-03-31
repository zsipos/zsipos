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
# confighelp.pxi
#
# Author: Esther Bergter
#
# Version 1.0


cdef Fl_Text_Buffer* helpTextBuffer

help_initialized = False

def help_init():
    global helpTextBuffer
    global help_intialized

    ui = configui
    helpTextBuffer = new Fl_Text_Buffer()
    ui.txt_helpDisplay.buffer(helpTextBuffer)
    ui.txt_helpDisplay.wrap_mode(3, 0) # 3=WRAP_AT_BOUNDS
    ui.txt_helpDisplay.scrollbar_width(20)
    ui.btn_help_back.callback(on_btn_help_back, NULL)
    help_initialized = True

cdef void on_btn_help(Fl_Widget* widget, void *data) with gil:
    label = get_label(get_value(configui.tab_config))
    #debug(label)
    if str(label) == str_ip_config:
        show_help('Help', help_ip_config)
    elif str(label) == str_server:
        show_help('Help', help_server)
    elif str(label) == str_experts:
        show_help('Help', help_experts)
    elif str(label) == str_reset:
        show_help('Help', help_reset)

# WinHelp
cdef void on_btn_help_back(Fl_Widget* widget, void *data) with gil:
    configui.txt_helpDisplay.copy_label('')
    helpTextBuffer.text('')
    configui.winHelp.hide()

def append_help(out):
    """ append text and show """
    helpTextBuffer.append(out)
    lines = configui.txt_helpDisplay.count_lines(0, helpTextBuffer.length(), False)
    #debug("disp.count_lines %d" % (lines, ))
    configui.txt_helpDisplay.scroll(lines, 0)
    configui.winHelp.flush()
    configui.winHelp.show()

def get_help_length():
    return helpTextBuffer.length()

def replace_help(mypos, lastpos, what):
    helpTextBuffer.replace(mypos, lastpos, what)

def show_help(label, out):
    """ show help window with label and display out """
    if not help_initialized:
        help_init()
    configui.txt_helpDisplay.copy_label(label)
    helpTextBuffer.text(out)
    lines = configui.txt_helpDisplay.count_lines(0, helpTextBuffer.length(), True)
    configui.txt_helpDisplay.scroll(lines, 0)
    configui.winHelp.wait_for_expose()
    configui.winHelp.flush()
    configui.winHelp.show()

