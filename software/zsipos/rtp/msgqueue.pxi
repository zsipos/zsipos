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
ctypedef void (*pj_mq_handler)(void *arg, int id, void *data) nogil

ctypedef struct msgd_t:
    int   id
    void* data
    int   magic
    
ctypedef struct pj_mq_t:
    pj_activesock_t* sock
    pj_sockaddr      addr
    pj_mq_handler    handler
    void*            arg
    msgd_t           rcvdata
    
DEF MSGDMAGIC = 0x16011967
    
cdef pj_bool_t pj_mq_on_data_recvfrom(pj_activesock_t*     asock, 
                                      void*                data, 
                                      pj_size_t            size, 
                                      const pj_sockaddr_t *src_addr, 
                                      int                  addr_len, 
                                      pj_status_t          status) nogil:
    cdef msgd_t* msgd
    cdef pj_mq_t* mq
    if status != PJ_SUCCESS:
        with gil: log.error("pj_mq_on_data_recvfrom(): status=%d", status)
        return True
    if size != sizeof(msgd_t):
        with gil: log.error("pj_mq_on_data_recvfrom(): wrong size")
        return True
    msgd = <msgd_t*>data
    if msgd.magic != MSGDMAGIC:
        with gil: log.error("pj_mq_on_data_recvfrom(): wrong magic")
        return True
    mq = <pj_mq_t*>pj_activesock_get_user_data(asock)
    mq.handler(mq.arg, msgd.id, msgd.data)
    return True
 
cdef pj_bool_t pj_mq_on_data_sent(pj_activesock_t* asock, pj_ioqueue_op_key_t* send_key, pj_ssize_t sent) nogil:
    free(send_key.user_data)
    free(send_key)
    return True

cdef pj_status_t pj_mq_create(pj_pool_t* pool, pj_ioqueue_t* ioq, pj_mq_handler handler, pj_mq_t** mq) nogil:
    cdef pj_activesock_cb callbacks
    cdef pj_status_t status
    cdef pj_str_t s
    cdef pj_sockaddr a
    mq[0] = <pj_mq_t*>pj_pool_zalloc(pool, sizeof(pj_mq_t))
    if not mq[0]:
        status = PJ_ENOMEM
        with gil: log.error("pj_pool_zalloc(): status=%d")
        return status
    mq[0].handler = handler
    memset(&callbacks, 0, sizeof(callbacks))
    callbacks.on_data_recvfrom = pj_mq_on_data_recvfrom
    callbacks.on_data_sent = pj_mq_on_data_sent
    pj_cstr(&s, "127.0.0.1")
    status = pj_sockaddr_init(pj_AF_INET(), &a, &s, 0)
    if status != PJ_SUCCESS:
        with gil: log.error("pj_sockaddr_init(): status=%d", status)
        return status
    cdef pj_activesock_cfg cfg
    pj_activesock_cfg_default(&cfg)
    cfg.async_cnt = MAXASYNC
    status = pj_activesock_create_udp(pool, &a, &cfg, ioq, &callbacks, <void*>mq[0], &mq[0].sock, &mq[0].addr)
    if status != PJ_SUCCESS:
        with gil: log.error("pj_activesock_create_udp(): status=%d", status)
        return status
    status = pj_activesock_start_recvfrom(mq[0].sock, pool, sizeof(msgd_t), PJ_IOQUEUE_ALWAYS_ASYNC)
    if status != PJ_SUCCESS:
        with gil: log.error("pj_activesock_start_recvfrom(): status=%d", status)
        return status
    return PJ_SUCCESS

cdef void pj_mq_close(pj_mq_t *mq) nogil:
    pj_activesock_close(mq.sock)

cdef pj_status_t pj_mq_put(pj_mq_t* mq, int id, void *data) nogil:
    cdef pj_status_t status
    cdef msgd_t *msg
    cdef pj_ssize_t len
    cdef pj_ioqueue_op_key_t *key
    key = <pj_ioqueue_op_key_t*>malloc(sizeof(pj_ioqueue_op_key_t))
    if not key:
        status = PJ_ENOMEM
        with gil: log.error("malloc(): status=%d", status)
        return status
    pj_ioqueue_op_key_init(key, sizeof(pj_ioqueue_op_key_t))
    len = sizeof(msgd_t)
    msg = <msgd_t*>malloc(len)
    if not msg:
        free(key)
        status = PJ_ENOMEM
        with gil: log.error("malloc(): status=%d", status)
        return status
    key.user_data = msg
    msg.id = id
    msg.data = data
    msg.magic = MSGDMAGIC
    status = pj_activesock_sendto(mq.sock, key, msg, &len, 0, &mq.addr.ipv4, sizeof(mq.addr.ipv4))
    if status == PJ_SUCCESS:
        free(msg)
        free(key)
    elif status == PJ_EPENDING:
        status = PJ_SUCCESS
    else:
        free(msg)
        free(key)
        with gil: log.error("pj_activesock_sendto(): status=%d", status)
    return status
