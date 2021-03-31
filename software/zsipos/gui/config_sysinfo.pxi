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
# config_sysinfo.pxi
#
# Author: Esther Bergter
#
# Version 1.0

sysinfo_initialized = False

# private modules
from gitversions import gitversions,gitdates
from utils import getGitMagic,gitFormat

cdef str str_gitversions = ''

#Group SysInfo
def group_sysinfo_init():
    global sysinfo_initialized

    ui = configui
    ui.btn_help.hide()

    if sysinfo_initialized:
        return

    ui.btn_zsipos_cfg.callback(on_btn_sysinfo, <void*>"zsipos.cfg")
    ui.btn_zsipos_log.callback(on_btn_sysinfo, <void*>"zsipos.log")
    ui.btn_nohup_out.callback(on_btn_sysinfo, <void*>"nohup.out")
    ui.btn_ifconfig.callback(on_btn_ifconfig, NULL)
    ui.btn_resolv_conf.callback(on_btn_sysinfo, <void*>"/etc/resolv.conf")
    ui.btn_messages.callback(on_btn_sysinfo, <void*>"/var/log/messages")
    gitout_init()
    gitversions_init()
    bootversion_init()
    ui.btn_show_git.callback(on_btn_show_git, NULL)
    sysinfo_initialized = True

# callbacks
cdef void on_btn_sysinfo(Fl_Widget *widget, void *data) with gil:
    show_sysinfo(<str>data)

cdef void on_btn_ifconfig(Fl_Widget *widget, void *data) with gil:
    show_ifconfig()

cdef void on_btn_show_git(Fl_Widget* widget, void *data) with gil:
    show_help("gitversion", str_gitversions)

# python
def bootversion_init():
    try:
        with open(bootversion_path, 'r') as f:
            for l in f.readlines():
                configui.out_bootversion.value(l.strip())
                break
    except:
        configui.out_bootversion.value('unknown bootversion')

def gitout_init():
    """ read gitMagic, FPGA, KERNEL-GIT """
    str_gitout = ("GIT-MAGIC: 0x%x\nFPGA-GIT: 0x%x\nKERNEL-GIT: 0x%x"
                   % (getGitMagic(), gitversions['FPGA-GIT'],
                      gitversions['KERNEL-GIT']))
    configui.out_git_magic.value(str_gitout)


def gitversions_init():
    ''' read gitversions into str '''
    global str_gitversions

    str_gitversions = '\n'.join(gitFormat(i) for i in gitversions)
    #debug(str_gitversions)

def show_ifconfig():
    try:
        out = subprocess.check_output(["ifconfig", ], encoding="utf8")
    except CalledProcessError:
        pass
    show_help("ifconfig", out)

def show_sysinfo(filename):
    try:
        out = subprocess.check_output(["tail", "-200", filename], stderr=subprocess.STDOUT, encoding="utf8")
    except CalledProcessError as e:
        if len(e.output):
            warn(e.output)
        else:
            warn(str(sys.exc_info()[1]))
        return
    show_help(filename, out)
