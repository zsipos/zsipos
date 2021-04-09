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
#configuifltk.pxi
#
# Author: Esther Bergter
#
# Version 1.0


#
# GUI class
#
cdef extern from "gui.cxx":

    cdef cppclass CONFIGUI:

        Fl_Double_Window*   window
        Fl_Button*          btn_back
        Fl_Button*          btn_help
        Fl_Button*          btn_warn
        Fl_Tabs*            tab_config
        # IP Config
        Fl_Group*           group_ip
        Fl_Group*           group_btn_dhcp
        Fl_Round_Button*    btn_dhcp
        Fl_Round_Button*    btn_static_ip
        Fl_Group*           group_btn_dns
        Fl_Round_Button*    btn_auto_dns
        Fl_Round_Button*    btn_static_dns
        Fl_Group*           group_static_ip
        Fl_Output*          btn_extphoneaddr
        Fl_Output*          btn_extgateway
        Fl_Output*          btn_extnetmask
        Fl_Button*          btn_ping_extgateway
        Fl_Group*           group_dns
        Fl_Output*          btn_dnsserver
        Fl_Button*          btn_ping_dnsserver
        # Server
        Fl_Group*           group_server
        Fl_Output*          btn_sipproxy
        Fl_Button*          btn_ping_sipproxy
        Fl_Output*          btn_icestorageurl
        Fl_Button*          btn_ping_icestorageurl
        Fl_Output*          btn_stunserver
        Fl_Button*          btn_ping_stunserver
        Fl_Output*          btn_turnserver
        Fl_Button*          btn_ping_turnserver
        Fl_Output*          btn_ntpserver
        Fl_Button*          btn_ping_ntpserver
        # Logging
        Fl_Group*           group_logs
        Fl_Button*          btn_logsettings
        Fl_Output*          btn_uploaduri
        Fl_Button*          btn_ping_uploaduri
        Fl_Check_Button*    btn_nohup
        Fl_Check_Button*    btn_zsiposlog
        Fl_File_Browser*    browse_archive
        Fl_Button*          btn_upload
        Fl_Round_Button*    btn_alternate_archive
        # LogSettings
        Fl_Double_Window*   winLogSettings
        Fl_Button*          btn_logsettings_back
        Fl_Check_Button*    log_external
        Fl_Check_Button*    log_local
        Fl_Check_Button*    log_full
        Fl_Check_Button*    log_cc_events
        Fl_Check_Button*    log_cc_messages
        Fl_Check_Button*    log_bm_events
        Fl_Check_Button*    log_timers
        Fl_Check_Button*    log_sip_proctime
        Fl_Check_Button*    log_sip_debug_delay
        Fl_Check_Button*    log_zrtp_events
        Fl_Check_Button*    log_zsession_events
        Fl_Check_Button*    log_ice
        Fl_Check_Button*    log_dtmf
        Fl_Counter*         log_level
        # Experts
        Fl_Group*           group_experts
        Fl_Output*          btn_localproxyaddr
        Fl_Button*          btn_ping_localproxyaddr
        Fl_Check_Button*    btn_skipzrtp1
        Fl_Check_Button*    btn_sshd
        Fl_Check_Button*    btn_autosshd
        # Password
        Fl_Group*           group_rootpw
        Fl_Button*          btn_rootpw
        # Reset
        Fl_Group*           group_reset
        Fl_Button*          btn_restart
        Fl_Button*          btn_reconfig
        Fl_Button*          btn_reboot
        Fl_Button*          btn_shutdown
        Fl_Button*          btn_calibrate
        Fl_Button*          btn_zid_reset
        Fl_Button*          btn_fac_reset
        # Sys Info
        Fl_Group*           group_sysinfo
        Fl_Button*          btn_zsipos_cfg
        Fl_Button*          btn_zsipos_log
        Fl_Button*          btn_nohup_out
        Fl_Button*          btn_ifconfig
        Fl_Button*          btn_resolv_conf
        Fl_Button*          btn_messages
        Fl_Button*          btn_show_git
        Fl_Output*          out_git_magic
        Fl_Output*          out_bootversion
        # Update
        Fl_Group*           group_update
        Fl_Output*          out_current_version
        Fl_Output*          out_alternate_version
        Fl_Group*           group_btn_bootversion
        Fl_Round_Button*    btn_boot_current
        Fl_Round_Button*    btn_boot_alternate
        Fl_Button*          btn_update_info

        # Are you sure?
        Fl_Double_Window*   winSure
        Fl_Box*             box_sure
        Fl_Button*          btn_sure_cancel
        Fl_Button*          btn_sure_ok

        # Save
        Fl_Double_Window*   winSave
        #Fl_Group*           group_save
        Fl_Button*          btn_save_and_restart
        Fl_Button*          btn_save_ok
        Fl_Button*          btn_save_cancel
        Fl_Box*             box_restart

        # Help
        Fl_Double_Window*   winHelp
        Fl_Button*          btn_help_back
        Fl_Text_Display*    txt_helpDisplay
        Fl_Text_Buffer*     helpTextBuffer
        Fl_Text_Buffer*     helpStyleBuffer

        # EditAddress
        Fl_Double_Window*   winEditAddress
        Fl_Group*           addressgroup
        Fl_Group*           ipgroup
        Fl_Input*           input_text
        Fl_Button*          btn_address_back
        Fl_Button*          btn_address_ok
        Fl_Button*          btn_address_next
        Fl_Button*          btn_address_cancel
        Fl_Button*          btn_address_warn
        # Url
        Fl_Round_Button*    btn_https

        # Keyboard Funktionskeys
        Fl_Group*           keyboardgroup_func
        Fl_Button*          key_del
        Fl_Button*          key_back
        Fl_Button*          key_forward
        Fl_Button*          key_123
        Fl_Button*          key_abc
        Fl_Button*          key_space
        Fl_Button*          key_shift

        # Keyboard alpha_lower
        Fl_Group*           keyboardgroup_alpha
        Fl_Button*          key_dot_alpha
        Fl_Button*          key_comma_alpha

        Fl_Group*           keyboardgroup_alpha_lower
        Fl_Button*          key_a
        Fl_Button*          key_b
        Fl_Button*          key_c
        Fl_Button*          key_d
        Fl_Button*          key_e
        Fl_Button*          key_f
        Fl_Button*          key_g
        Fl_Button*          key_h
        Fl_Button*          key_i
        Fl_Button*          key_j
        Fl_Button*          key_k
        Fl_Button*          key_l
        Fl_Button*          key_m
        Fl_Button*          key_n
        Fl_Button*          key_o
        Fl_Button*          key_p
        Fl_Button*          key_q
        Fl_Button*          key_r
        Fl_Button*          key_s
        Fl_Button*          key_t
        Fl_Button*          key_u
        Fl_Button*          key_v
        Fl_Button*          key_w
        Fl_Button*          key_x
        Fl_Button*          key_y
        Fl_Button*          key_z

        Fl_Group*           keyboardgroup_alpha_upper
        Fl_Button*          key_A
        Fl_Button*          key_B
        Fl_Button*          key_C
        Fl_Button*          key_D
        Fl_Button*          key_E
        Fl_Button*          key_F
        Fl_Button*          key_G
        Fl_Button*          key_H
        Fl_Button*          key_I
        Fl_Button*          key_J
        Fl_Button*          key_K
        Fl_Button*          key_L
        Fl_Button*          key_M
        Fl_Button*          key_N
        Fl_Button*          key_O
        Fl_Button*          key_P
        Fl_Button*          key_Q
        Fl_Button*          key_R
        Fl_Button*          key_S
        Fl_Button*          key_T
        Fl_Button*          key_U
        Fl_Button*          key_V
        Fl_Button*          key_W
        Fl_Button*          key_X
        Fl_Button*          key_Y
        Fl_Button*          key_Z

        # Keyboard numerisch
        Fl_Group*           keyboardgroup_num
        Fl_Button*          key_1
        Fl_Button*          key_2
        Fl_Button*          key_3
        Fl_Button*          key_4
        Fl_Button*          key_5
        Fl_Button*          key_6
        Fl_Button*          key_7
        Fl_Button*          key_8
        Fl_Button*          key_9
        Fl_Button*          key_0
        Fl_Button*          key_at
        Fl_Button*          key_colon
        Fl_Button*          key_semicolon
        Fl_Button*          key_underscore
        Fl_Button*          key_minus
        Fl_Button*          key_hash
        Fl_Button*          key_lparenthesis
        Fl_Button*          key_rparenthesis
        Fl_Button*          key_slash
        Fl_Button*          key_plus
        Fl_Button*          key_dot_num
        Fl_Button*          key_comma_num
        Fl_Button*          key_question
        Fl_Button*          key_exclamation
        Fl_Button*          key_singlequote
        Fl_Button*          key_doublequote

        # UpdateInfo
        Fl_Double_Window*   winUpdateInfo
        Fl_Button*          btn_updateinfo_back
        Fl_Output*          btn_updateuri
        Fl_Button*          btn_ping_updateuri
        Fl_Text_Display*    txt_updateinfo
        Fl_Button*          btn_updateinfo_ok

        # Update Progress
        Fl_Double_Window*   winUpdateProgress
        Fl_Text_Display*    txt_updateprogress
        #Fl_Button*          btn_updateprogress_back
        Fl_Button*          btn_updateprogress_cancel
        Fl_Button*          btn_updateprogress_reboot
        #Fl_Box*             box_updateprogress_reboot_warn

        # EditHex
        Fl_Double_Window*   winEditHex
        Fl_Button*          btn_hex_back
        Fl_Button*          btn_hex_ok
        Fl_Button*          btn_hex_cancel
        Fl_Group*           hexgroup
        Fl_Input*           input_hex
        Fl_Button*          btn_hex_warn

        # Keyboard hex Funktionskeys
        Fl_Group*           keyboardgroup_hex_func
        Fl_Button*          key_hex_del
        Fl_Button*          key_hex_back
        Fl_Button*          key_hex_forward

        # Keyboard hex
        Fl_Group*           keyboardgroup_hex
        Fl_Button*          key_h1
        Fl_Button*          key_h2
        Fl_Button*          key_h3
        Fl_Button*          key_h4
        Fl_Button*          key_h5
        Fl_Button*          key_h6
        Fl_Button*          key_h7
        Fl_Button*          key_h8
        Fl_Button*          key_h9
        Fl_Button*          key_h0
        Fl_Button*          key_hA
        Fl_Button*          key_hB
        Fl_Button*          key_hC
        Fl_Button*          key_hD
        Fl_Button*          key_hE
        Fl_Button*          key_hF

        CONFIGUI() nogil

