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
# config_reset.pxi
#
# Author: Esther Bergter
#
# Version 1.0

reset_initialized = False

# Group Reset
def group_reset_init():
    global reset_initialized

    ui = configui
    ui.btn_help.show()

    if reset_initialized:
        return

    ui.btn_restart.callback(on_btn_restart, <void*>'restart')
    ui.btn_reconfig.callback(on_btn_restart, <void*>'reconfig')
    ui.btn_reboot.callback(on_btn_restart, <void*>'reboot')
    ui.btn_shutdown.callback(on_btn_restart, <void*>'shutdown')
    ui.btn_nxcal.callback(on_btn_nxcal, NULL)
    ui.btn_zid_reset.callback(on_btn_zid_reset, NULL)
    ui.btn_fac_reset.callback(on_btn_fac_reset, NULL)
    reset_initialized = True

# callbacks
cdef void on_btn_restart(Fl_Widget* widget, void *data) with gil:
    restart_type = <str>data
    #debug(restart_type)
    if config_has_changed():
        cfg_cleanup()
        info = "config has changed, %s requested" % (restart_type,)
        show_save(info, restart_type)
    else:
        do_restart(restart_type)

cdef void on_btn_fac_reset(Fl_Widget* widget, void *data) with gil:
    #debug("btn_fac_reset")
    if issel4():
        #debug('factory reset')
        for file in (consts.CFGFILE, consts.ZIDFILE, consts.NDBFILE):
            if os.path.isfile(file):
                log.info("remove "+file)
                os.remove(file)
        log.info("factory reset, reboot system")
        os.system('reboot')
    else:
        what = 'factory reset requested'
        info(f"TestModus {what}")
        log.info(what)

cdef void on_btn_nxcal(Fl_Widget* widget, void *data) with gil:
    if issel4():
        configui.window.hide()
        os.unlink('/etc/pointercal')
        os.system('export TSLIB_TSDEVICE=/dev/input/event0;/usr/bin/ts_calibrate')
        configui.window.show()
    else:
        what = 'calibration requested'
        info(f"TestModus {what}")
        log.info(what)

cdef void on_btn_zid_reset(Fl_Widget* widget, void *data) with gil:
    all = ''
    for file in (consts.ZIDFILE, consts.NDBFILE):
        if os.path.isfile(file):
            what = f'{file} removed'
            os.remove(file)
            log.info(what)
            if len(all):
                all += f', {file}'
            else:
                all = file
    if len(all):
        info(f'{all} removed')
    else:
        info('nothing to remove')

