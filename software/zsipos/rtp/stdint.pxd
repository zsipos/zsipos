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
cdef extern from "stdint.h":

    ctypedef          char       int8_t               
    ctypedef unsigned char      uint8_t
    ctypedef          short      int16_t
    ctypedef unsigned short     uint16_t
    ctypedef          int        int32_t
    ctypedef unsigned int       uint32_t
    ctypedef          long long  int64_t
    ctypedef unsigned long long uint64_t
