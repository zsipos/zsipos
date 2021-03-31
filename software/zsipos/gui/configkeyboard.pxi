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
# configkeyboard.pxi
#
# Author: Esther Bergter
#
# Version 1.0


keyboard_initialized = False

def keyboard_init():
    global configui
    global keyboard_initialized

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
    keyboard_initialized = True
# keyboard_init

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

#python

def keyboard_show(key_state):
    # Keyboard callbacks
    if not keyboard_initialized:
        keyboard_init()

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
