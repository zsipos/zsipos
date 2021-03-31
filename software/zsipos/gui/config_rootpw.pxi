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
# config_rootpw.pxi
#
# Author: Esther Bergter
#
# Version 1.0

cdef str newpw = ''
rootpw_initialized = False

# Group Password
def group_rootpw_init():
    global rootpw_initialized

    ui = configui
    ui.btn_help.hide()

    if rootpw_initialized:
        return
    ui.btn_rootpw.callback(on_btn_rootpw, <void*>'rootpw')
    rootpw_initialized = True

class EditAddress_rootpw(EditAddress):
    def init(self):
        """ init from type """

        type = self.type
        self.title = "Change root password"
        self.estep = 0 # first step

        if type == 'rootpw':
            self.steps = 3
            self.heads = ["old password", "new_password", "repeat new password"]
            self.editvals = ['', '', '']
            self.keyboard = ['abc', 'abc', 'abc']
            self.testfunctions = [self.oldpwtest, storenewpw, comparepw]
            self.warnings = ['Password is wrong.', 'Minimum password length is 6', 'Passwords do not match.']
        elif type == 'initrootpw':
            self.steps = 2
            self.heads = ["new_password", "repeat new password"]
            self.editvals = ['', '']
            self.keyboard = ['abc', 'abc']
            self.testfunctions = [storenewpw, comparepw]
            self.warnings = ['Minimum password length is 6', 'Passwords do not match.']
        else:
            raise Exception("unknown type {}".format(type))
        self.debug_editval("EditAddress_rootpw init")

    def oldpwtest(self, testpw):
        debug(f'oldpwtest {testpw}')
        try:
            oldorig = spwd.getspnam('root')
        except PermissionError:
            if issel4():
                info = sys.exc_info()
                self.EditWindow.warning = f'{info[1]}\nare you root?'
                return False
            else:
                log.info("not on sel4, cannot read /etc/shadow, ok")
                return True
        except KeyError:
            info = sys.exc_info()
            self.EditWindow.warning = f'{info[1]}\nare you root?'
            return False
        if len(oldorig.sp_pwd) == 0:
            log.info("oldpwtest: root password is empty, ok")
            return True
        #debug(testpw)
        if crypt.crypt(testpw, oldorig.sp_pwd) == oldorig.sp_pwd:
            log.info("oldpwtest: root password ok")
            #debug('oldpw ok')
            return True
        else:
            self.EditWindow.warning = 'Password is wrong.'
            return False

    def save(self):
        global root_pw_is_set

        if issel4():
            cmd = ['/usr/bin/passwd', 'root']
            PIPE=subprocess.PIPE
            p = subprocess.Popen(cmd, stdin=PIPE, stderr=PIPE, stdout=PIPE, encoding="utf8")
            input = u'%(p)s\n%(p)s\n' % { 'p': newpw }
            (out,err) = p.communicate(input)
            if p.returncode == 0:
                out = out.strip()
                root_pw_is_set = True
                return (p.returncode, str(out))
            else:
                err = err.strip()
                return (p.returncode, str(err))
        else:
            root_pw_is_set = True
            what =f'save_root_pw {newpw} requested'
            info(f"TestModus {what}")
            log.info(what)
            return(0,"")

cdef void on_btn_rootpw(Fl_Widget *widget, void *data) with gil:
    global my_edit
    mytype = <str>data
    class Edit_rootpw(EditAddress_rootpw):
        def __init__(self):
            nonlocal mytype
            super().__init__(type=mytype)

        def OkPressed(self):
            debug("OkPressed")

        def Cancel(self):
            debug("Cancel")

    my_edit = Edit_rootpw()

def comparepw(pw):
    """ compare passwords """
    #debug("comparepw: {} {}".format(newpw, pw))
    if newpw == pw:
        return True
    else:
        return False

def storenewpw(pw):
    """ copy input to newpw """
    global newpw
    if len(pw) < 6:
        return False
    newpw = pw
    return True

