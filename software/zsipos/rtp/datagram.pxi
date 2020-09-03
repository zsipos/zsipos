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
 
ctypedef void (*pjDatagramRcvCallback)(void*                arg, 
                                       const pj_sockaddr_t* addr, 
                                       int                  addrlen, 
                                       void*                databuf,
                                       pj_size_t            datalen) nogil

cdef class PJDatagramSock:

    cdef pjDatagramRcvCallback rcvCallback
    cdef void*                 rcvCallbackArg

    cdef void setRcvCallback(self, pjDatagramRcvCallback cb, void* arg) nogil:
        self.rcvCallback = cb
        self.rcvCallbackArg = arg

    cdef void dataReceived(self, const pj_sockaddr_t* addr, int addrlen, pj_uint8_t* databuf, pj_size_t datalen) nogil:
        #tp be overwritten, or use callback
        self.rcvCallback(self.rcvCallbackArg, addr, addrlen, databuf, datalen)
    
    cdef pj_status_t sendData(self, const pj_sockaddr_t* addr, int addrlen, pj_uint8_t* databuf, pj_size_t datalen) nogil:
        #to be overwritten
        pass
    
    def close(self):
        #to be overwritten
        pass
    


