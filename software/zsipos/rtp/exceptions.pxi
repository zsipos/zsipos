# SPDX-FileCopyrightText: 2019 Stefan Adams <stefan.adams@vipcomag.de>
#
# SPDX-License-Identifier: GPL-3.0-or-later

"""
Copyright (C) 2017 Stefan Adams

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

class RTPException(Exception):
    
    def __init__(self, code, msg = None):
        errmsg = status2str(code)
        if msg: errmsg += msg
        super(RTPException, self).__init__(errmsg)
        self.code = code
        self.msg = errmsg
        
def raise_re_exception(code, msg = None):
    raise RTPException(code, msg)

def re_check_error(code, msg = None):
    if code:
        raise_re_exception(code, msg)
        
def pj_raise_exception(status, msg = None):
    raise RTPException(status, msg)

def pj_check_status(status, msg = None):
    if status:
        pj_raise_exception(status, msg)
        
