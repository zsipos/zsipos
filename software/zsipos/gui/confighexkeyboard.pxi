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
# confighexkeyboard.pxi
#
# Author: Esther Bergter
#
# Version 1.0

keyboardhex_initialized = False

def keyboardhex_init():
    global keyboardhex_initialized

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
    keyboardhex_initialized = True

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

def collapse_hexbuf(whitestring):
    return "".join(whitestring.split())

def collapse_hexpos(whitepos):
    blocklen = 5
    blocks = int(whitepos/blocklen)
    #debug("whitepos %d, blocks %d" % (whitepos, blocks))
    return whitepos-blocks

def cut(s, i):
    """ cut char at pos i from string """
    debug("cut %s %d" % (s,i))
    if i < 0:
        return s
    result = s[:i] + s[i+1:]
    debug("result %s" % (result,))
    return result

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

def get_hexbuf():
    return collapse_hexbuf(get_value(configui.input_hex))

def restore_hexedit(hexbuf, collapsed_pos):
    newvalue = expand_hexbuf(hexbuf)
    newpos = expand_hexpos(collapsed_pos)
    configui.input_hex.value(newvalue)
    configui.input_hex.position(newpos, newpos)

def show_keyboardhex():
    if not keyboardhex_initialized:
        keyboardhex_init()
    if is_testversion():
        configui.btn_hex_back.show()
    else:
        configui.btn_hex_back.hide()
    configui.input_hex.value("")
    configui.winEditHex.show()
