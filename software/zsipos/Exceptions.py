# SPDX-FileCopyrightText: 2019 Stefan Adams <stefan.adams@vipcomag.de
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
from sys import exc_info

class ZsiposException(Exception):
    def __init__(self, *args, **kwargs):
        super(ZsiposException, self).__init__(*args, **kwargs)
        self.caused_by = exc_info()

class ZsiposCfgException(ZsiposException):
    def __init__(self, *args, **kwargs):
        tab = kwargs.get('config_tab')
        if tab:
            self.config_tab = tab;
            del kwargs['config_tab']
        else:
            self.config_tab = 1;
        super(ZsiposCfgException, self).__init__(*args, **kwargs)
