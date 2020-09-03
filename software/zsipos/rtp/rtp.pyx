# SPDX-FileCopyrightText: 2019 Stefan Adams <stefan.adams@vipcomag.de>
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

# This are the toplevel definitions for the rtp module.
# All classes are implemented as includes, to have less cython overhead.

#from __builtin__ import None
from libc.string cimport memcpy, memset
from libc.stdlib cimport malloc, free
from libcpp cimport bool
from libcpp.string cimport string
from sys import exc_info, modules
import json
import logging
import urllib.request
import urllib.error

from stdint cimport *
cimport zrtp
cimport srtp
from pj cimport *
import consts
from config import config
from utils import PYCALL, udpprotocol

log  = logging.getLogger("rtpstream")
logz = logging.getLogger("zrtpcpp")
logs = logging.getLogger("zsession")
logi = logging.getLogger("ice")
logr = logging.getLogger("libre")
logp = logging.getLogger("libpj")
logd = logging.getLogger("dtmf")

#max rtp packet length
DEF MAXRTPLEN = 8192
#max async calls
DEF MAXASYNC = 1
#nr sockets / call
DEF SOCKS1CALL = 16 # 8
#nr timers / call
DEF TIMERS1CALL = 128
#nr of calls
DEF MAXCALLS = 4
#keepalive timeout
DEF KEEPALIVESECS = 5

#rtp stream names
DEF _AUDIOSTREAM = 0
DEF _VIDEOSTREAM = 1
AUDIOSTREAM = _AUDIOSTREAM
VIDEOSTREAM = _VIDEOSTREAM

ctypedef enum ZrtpStates:
    ZRTP_STATE_NONE,
    ZRTP_STATE_STARTED,
    ZRTP_STATE_CONNECTED,
    ZRTP_STATE_FAILED
    
ctypedef enum IceStates:
    ICE_STATE_NONE,
    ICE_STATE_STARTED,
    ICE_STATE_CONNECTED,
    ICE_STATE_FAILED

# informational only, no rtp logic driven by this!
ctypedef enum CryptoStateInfo:
    CRYPTO_STATEINFO_NONE,           # direct rtp connection
    CRYPTO_STATEINFO_ZRTP1,          # trying 1. zrtp connection
    CRYPTO_STATEINFO_LOCAL_OFFER,    # calculate ice local offer
    CRYPTO_STATEINFO_DTMF_EXCHANGE,  # dtmf exchange: sending offerid
    CRYPTO_STATEINFO_ICE,            # ice phase
    CRYPTO_STATEINFO_ZRTP2,          # trying 2. zrtp connection (using ice connection)
    CRYPTO_STATEINFO_CONNECTED,      # 1. final state: everything connected + encrypted
    CRYPTO_STATEINFO_FAILED          # 2. final state: failed 

cdef struct AUDIOINFO:
    int  rate
    int  ptime
    bool pcmu
    int  pt
    int  ticks1ms
    
#
# We have two threads, with two ioqueues:
# rtp_thread mainly pumps the rtp packages
# zrtp_thread handles the zrtp handshake (to allow data pumping during handshake)
#

#thread ids
DEF RTP_THREAD = 0
DEF ZRTP_THREAD = 1

include "pjhelpers.pxi"
include "msgqueue.pxi"

ctypedef struct RTPGLOBALS:
    pj_caching_pool  caching_pool
    pj_pool_t*       pool
    pj_lock_t*       rtp_lock
    pj_lock_t*       zrtp_lock
    pj_timer_heap_t* rtp_timer_heap
    pj_timer_heap_t* zrtp_timer_heap
    pj_ioqueue_t*    rtp_ioq
    pj_ioqueue_t*    zrtp_ioq
    bool             stop_rtp_thread   
    bool             stop_zrtp_thread
    pj_thread_t*     rtp_thread 
    pj_thread_t*     zrtp_thread  
    pj_mq_t*         rtp_mq 
    pj_mq_t*         zrtp_mq
    
cdef RTPGLOBALS g
            
#
# callback helpers, to delegate data to specific thread
#            
cdef extern from *: #@DuplicateSignature

    cdef void __Pyx_INCREF(void*) nogil    
    cdef void __Pyx_DECREF(void*) nogil
        
cdef struct MQCBDATA            
ctypedef void (*mq_handler_t)(void* obj, void* data) nogil

cdef struct MQCBDATA:
    # union
    # c-call with rtp packet
    mq_handler_t func
    void*        obj
    pj_uint8_t*  databuf
    pj_size_t    datalen
    uint32_t     ssrc
    # python call
    void*        pycall
    
cdef void mq_handler_c(MQCBDATA* cbdata) nogil:
    cbdata.func(cbdata.obj, cbdata)
    if cbdata.obj:
        __Pyx_DECREF(cbdata.obj)
    
cdef void mq_handler_python(void *obj) with gil:
    try:
        pycall = <object>obj
        pycall.call()
    finally: 
        __Pyx_DECREF(obj)

cdef void mq_handler(void *arg, int id, void *data) nogil:
    cdef MQCBDATA* cbdata = <MQCBDATA*>data
    if cbdata.func: 
        mq_handler_c(cbdata)
    elif cbdata.pycall:
        mq_handler_python(cbdata.pycall)
    free(data)

cdef pj_status_t mq_call(pj_mq_t* mq, mq_handler_t func, void* obj, MQCBDATA* data) nogil:
    cdef MQCBDATA* cbdata = <MQCBDATA*>malloc(sizeof(MQCBDATA))
    if not cbdata:
        return PJ_ENOMEM
    if data:
        memcpy(cbdata, data, sizeof(MQCBDATA))
    else:
        pj_memset(cbdata, 0, sizeof(MQCBDATA))
    cbdata.func = func
    cbdata.obj = obj
    if cbdata.obj:
        __Pyx_INCREF(cbdata.obj)
    return pj_mq_put(mq, 0, cbdata)

def mq_pycall(int quenr, func, args, kwargs):
    global g
    cdef MQCBDATA* cbdata = <MQCBDATA*>malloc(sizeof(MQCBDATA))
    if not cbdata: 
        pj_check_status(PJ_ENOMEM)
    pj_memset(cbdata, 0, sizeof(MQCBDATA))
    cargs = PYCALL(func, args, kwargs)
    cbdata.pycall = <void*>cargs
    __Pyx_INCREF(cbdata.pycall)
    cdef pj_mq_t *mq
    if quenr == RTP_THREAD:
        mq = g.rtp_mq
    elif quenr == ZRTP_THREAD:
        mq = g.zrtp_mq
    else:
        assert False, "quenr %d out of range (0-1)" % (quenr)
    cdef pj_status_t status
    status = pj_mq_put(mq, 0, cbdata)
    pj_check_status(status)
    
def callRTP(func, *args, **kwargs):
    mq_pycall(RTP_THREAD, func, args, kwargs)
    
def callZRTP(func, *args, **kwargs):
    mq_pycall(ZRTP_THREAD, func, args, kwargs)
    
cdef int rtp_threadproc(void *arg) nogil:
    set_realtime()
    cdef pj_time_val tv
    while not g.stop_rtp_thread:
        tv.sec = 0
        tv.msec = 200
        pj_ioqueue_poll(g.rtp_ioq, &tv)
        pj_timer_heap_poll(g.rtp_timer_heap, NULL)
    g.stop_rtp_thread = False

cdef int zrtp_threadproc(void *arg) nogil:
    cdef pj_time_val tv
    while not g.stop_zrtp_thread:
        tv.sec = 0
        tv.msec = 200
        pj_ioqueue_poll(g.zrtp_ioq, &tv)
        pj_timer_heap_poll(g.zrtp_timer_heap, NULL)
    g.stop_zrtp_thread = False
    
cdef extern from "../rtp.h":
    cdef pj_status_t init_crypt_engine() nogil
    cdef void clog(const char* sender, int level, const char* fmt, ...) nogil
    
#
# init
#
cdef void pjlogfunc(int level, const char* data, int len) with gil:
    #TODO: perhaps honor level ...
    val = data[:len]
    if val[-1] == "\n":
        val = val[:-1]
    logp.debug("[%d] %s", level, val)
    
def pjinit():
    global g
    init_crypt_engine()
    pj_memset(&g, 0, sizeof(RTPGLOBALS))
    pj_log_set_level(config.getint(consts.SECTION, consts.PJLOGLEVEL))
    cdef pj_status_t status = pj_init()
    pj_check_status(status)
    status = pjlib_util_init()
    pj_check_status(status)
    status = pjnath_init()
    pj_check_status(status)
    pj_caching_pool_init(&g.caching_pool, NULL, 0)
    g.pool = pj_pool_create(&g.caching_pool.factory, "rtp_pool", 256, 512, NULL)
    if not g.pool:
        pj_raise_exception(PJ_ENOMEM)
    status = pj_lock_create_recursive_mutex(g.pool, "rtp_lock", &g.rtp_lock)
    pj_check_status(status)
    status = pj_lock_create_recursive_mutex(g.pool, "zrtp_lock", &g.zrtp_lock)
    pj_check_status(status)
    status = pj_timer_heap_create(g.pool, TIMERS1CALL * MAXCALLS, &g.rtp_timer_heap)
    pj_check_status(status)
    status = pj_timer_heap_create(g.pool, MAXCALLS * 64, &g.zrtp_timer_heap)
    pj_check_status(status)
    status = pj_ioqueue_create(g.pool, SOCKS1CALL * MAXCALLS, &g.rtp_ioq)
    pj_check_status(status)
    status = pj_ioqueue_create(g.pool, 1, &g.zrtp_ioq)
    pj_check_status(status)
    pj_ioqueue_set_lock(g.rtp_ioq, g.rtp_lock, PJ_FALSE)
    pj_ioqueue_set_lock(g.zrtp_ioq, g.zrtp_lock, PJ_FALSE)
    status = pj_mq_create(g.pool, g.rtp_ioq, mq_handler, &g.rtp_mq)
    pj_check_status(status)
    status = pj_mq_create(g.pool, g.zrtp_ioq, mq_handler, &g.zrtp_mq)
    pj_check_status(status)
    status = pj_thread_create(g.pool, "rtp_thread", rtp_threadproc, NULL, 0, 0, &g.rtp_thread)
    pj_check_status(status)
    status = pj_thread_create(g.pool, "zrtp_thread", zrtp_threadproc, NULL, 0, 0, &g.zrtp_thread)
    pj_check_status(status)
        
def pjexit():
    global g
    if g.zrtp_thread:
        g.stop_zrtp_thread = True 
        pj_thread_join(g.zrtp_thread)
        pj_thread_destroy(g.zrtp_thread)
    if g.rtp_thread:
        g.stop_rtp_thread = True 
        pj_thread_join(g.rtp_thread)
        pj_thread_destroy(g.rtp_thread)
    if g.zrtp_mq: pj_mq_close(g.zrtp_mq)
    if g.rtp_mq : pj_mq_close(g.rtp_mq)
    if g.zrtp_ioq: pj_ioqueue_destroy(g.zrtp_ioq)
    if g.rtp_ioq : pj_ioqueue_destroy(g.rtp_ioq)
    if g.zrtp_timer_heap: pj_timer_heap_destroy(g.zrtp_timer_heap)
    if g.rtp_timer_heap : pj_timer_heap_destroy(g.rtp_timer_heap)
    if g.zrtp_lock: pj_lock_destroy(g.zrtp_lock)
    if g.rtp_lock: pj_lock_destroy(g.rtp_lock)
    if g.pool: pj_pool_release(g.pool)
    pj_caching_pool_destroy(&g.caching_pool)
    pj_memset(&g, 0, sizeof(g))
    pj_shutdown()

# init python threads
cdef extern from "Python.h":

    cdef void PyEval_InitThreads()
    
PyEval_InitThreads()

# set default signals
cdef extern from "signal.h":

    ctypedef void (*sighandler_t)(int)

    cdef int SIGABRT
    cdef int SIGSEGV
    
    cdef sighandler_t SIG_DFL
    
    cdef void signal(int, sighandler_t) nogil

cdef void defaultsigs() nogil:
    signal(SIGABRT, SIG_DFL) 
    signal(SIGSEGV, SIG_DFL) 
    
# set realtime priority
cdef extern from "pthread.h":

    ctypedef struct sched_param:
        int sched_priority
        
    ctypedef unsigned long pthread_t
        
    cdef int SCHED_FIFO
    cdef int SCHED_RR
    
    cdef pthread_t pthread_self() nogil
    cdef int       pthread_setschedparam(pthread_t thread, int policy, const sched_param* param) nogil
    
cdef int set_realtime() nogil:
    cdef sched_param param 
    memset(&param, 0, sizeof(param))
    param.sched_priority = 1
    return pthread_setschedparam(pthread_self(), SCHED_FIFO, &param)
    
#
# external interface
#

def init():
    pjinit()
    
def postinit():
    defaultsigs()

def close():
    pjexit()
    
cdef void wake_rtp_thread() nogil:
    mq_call(g.rtp_mq, NULL, NULL, NULL)
    
cdef pj_thread_desc gui_thread_desc
cdef pj_thread_t*   gui_thread_handle

def register_gui_thread():
    pj_thread_register("gui_thread", gui_thread_desc, &gui_thread_handle)

include "enums.pxi"    
include "exceptions.pxi"
include "datagram.pxi"
include "udp.pxi"
include "icestream.pxi"
include "dtmfexchange.pxi"
include "zstream.pxi"
include "zsession.pxi"

