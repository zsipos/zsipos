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
    
#
# Helpers to pass PJ objects in cython objects
#

cdef class PJPool(object):

    cdef pj_pool_t* p

    cdef void set_pool(self, pj_pool_t* pool) nogil:
        self.p = pool

        
cdef get_pool(pj_pool_t* pool):
    ret = PJPool()
    ret.set_pool(pool)
    return ret

        
cdef class PJIOQueue(object):

    cdef pj_ioqueue_t* p

    cdef void set_ioq(self, pj_ioqueue_t* ioq) nogil:
        self.p = ioq

        
cdef get_ioq(pj_ioqueue_t* ioq):
    ret = PJIOQueue()
    ret.set_ioq(ioq)
    return ret

cdef status2str(pj_status_t status):
    cdef char errname[512]
    cdef pj_str_t pjerrstr
    pjerrstr = pj_strerror(status, errname, sizeof(errname))
    return str(status) + ", " + pjerrstr.ptr[:pjerrstr.slen]
