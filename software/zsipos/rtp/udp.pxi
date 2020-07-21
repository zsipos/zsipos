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

cdef class PJUDPSock(PJDatagramSock):

    cdef pj_uint8_t           buffer[MAXASYNC][MAXRTPLEN]
    cdef void*                databufs[MAXASYNC]
    cdef pj_size_t            datalen
    cdef pj_size_t            maxlen
    cdef pj_sock_t            sock
    cdef pj_activesock_t     *asock
    cdef pj_ioqueue_op_key_t  send_key   
    
    def __cinit__(self):
        self.sock = PJ_INVALID_SOCKET
        
    def __dealloc__(self):
        self.close()
            
    def __init__(self, PJPool pool, PJIOQueue ioq, addr, int protocol = 0, int maxlen = MAXRTPLEN, pj_qos_type qos_type = PJ_QOS_TYPE_BEST_EFFORT):
        global g
        self.maxlen = maxlen
        for i in xrange(MAXASYNC):
            self.databufs[i] = <void*>&self.buffer[i]
        pj_ioqueue_op_key_init(&self.send_key, sizeof(self.send_key))
        cdef pj_str_t tmpstr
        cdef pj_sockaddr saddr
        cdef pj_status_t status
        pj_cstr(&tmpstr, addr[0])
        status = pj_sockaddr_init(pj_AF_INET(), &saddr, &tmpstr, addr[1])
        pj_check_status(status)
        status = pj_sock_socket(saddr.addr.sa_family, pj_SOCK_DGRAM(), protocol, &self.sock)
        pj_check_status(status)
        status = pj_sock_set_qos_type(self.sock, qos_type)
        pj_check_status(status)
        status = pj_sock_bind(self.sock, <pj_sockaddr_t*>&saddr.ipv4, sizeof(saddr.ipv4))
        pj_check_status(status)
        cdef pj_activesock_cb cb
        pj_memset(&cb, 0, sizeof(cb))
        cb.on_data_recvfrom = PJUDPSock_on_data_recvfrom
        cdef pj_activesock_cfg cfg
        pj_activesock_cfg_default(&cfg)
        cfg.async_cnt = MAXASYNC
        status = pj_activesock_create(pool.p, self.sock, pj_SOCK_DGRAM(), &cfg, ioq.p, &cb, <void*>self, &self.asock)
        pj_check_status(status)
        status = pj_activesock_start_recvfrom2(self.asock, pool.p, maxlen, self.databufs, PJ_IOQUEUE_ALWAYS_ASYNC)
        pj_check_status(status)
        
    cdef void close(self) nogil:
        if self.asock:
            pj_activesock_close(self.asock)
            self.asock = NULL
        if self.sock != PJ_INVALID_SOCKET:
            pj_sock_close(self.sock)
            self.sock = PJ_INVALID_SOCKET
            
    cdef pj_status_t sendData(self, const pj_sockaddr_t* addr, int addrlen, pj_uint8_t* databuf, pj_size_t datalen) nogil:
        cdef pj_ssize_t ssdatalen = datalen
        cdef pj_status_t status = pj_activesock_sendto(self.asock, &self.send_key, databuf, &ssdatalen, 0, addr, addrlen)
        if status == PJ_EPENDING:
            clog("udp", 1, "packet is queued")
        return status
    
    def getsockname(self):
        cdef pj_sockaddr addr
        cdef pj_sockaddr_t *paddr = <pj_sockaddr_t*>&addr
        cdef int addrlen = sizeof(addr)
        cdef pj_status_t status = pj_sock_getsockname(self.sock, paddr, &addrlen)
        cdef char buf[512]
        return ( pj_sockaddr_print(paddr, buf, sizeof(buf), 2),  pj_sockaddr_get_port(paddr) )
    
    cdef void flush(self) nogil:
        cdef pj_ssize_t len = self.maxlen
        while pj_sock_recvfrom(self.sock, self.databufs[0], &len, 0, NULL, NULL) == PJ_SUCCESS:
            #do nothing
            len = self.maxlen
    
    # callbacks
    
    cdef pj_bool_t on_data_recvfrom(self, 
                                    void*                data, 
                                    pj_size_t            size, 
                                    const pj_sockaddr_t* src_addr, 
                                    int                  addr_len, 
                                    pj_status_t          status) nogil:
        if status != PJ_SUCCESS: 
            clog("udp", 1, "on_data_recfrom(): status=%d", status)
            return PJ_TRUE
        self.dataReceived(src_addr, addr_len, <pj_uint8_t*>data, size)
        return PJ_TRUE 


# callbacks glue

cdef pj_bool_t PJUDPSock_on_data_recvfrom (pj_activesock_t*     asock, 
                                           void*                data, 
                                           pj_size_t            size, 
                                           const pj_sockaddr_t* src_addr, 
                                           int                  addr_len, 
                                           pj_status_t          status) nogil:
    return (<PJUDPSock>pj_activesock_get_user_data(asock)).on_data_recvfrom(data, size, src_addr, addr_len, status)
