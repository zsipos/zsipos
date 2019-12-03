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

DEF _PJ_ICE_MAX_CAND = 16

ctypedef enum compid_t:
    COMPID_RTP = 1,
    COMPID_RTCP

class PostRequest(urllib.request.Request):
    
    def get_method(self):
        return "POST"

    
class PutRequest(urllib.request.Request):
    
    def get_method(self):
        return "PUT"


cdef class PJICEStream:

    cdef pj_ice_sess_role  role
    cdef object            host        # just the string
    cdef object            storageurl
    cdef object            dns_server  # tuple(addr, port)
    cdef object            stun_server # tuple(addr, port)
    cdef object            turn_server # tuple(addr, port)
    cdef object            turn_user
    cdef object            turn_pwd
    cdef pj_ice_strans_cfg cfg
    cdef pj_ice_strans*    ice_st
    cdef pj_dns_resolver*  resolver
    
    cdef bool flushing
    cdef bool had_packet
    
    cdef object           localid
    cdef object           token
    cdef object           remote_id
    cdef object           remote_data
    cdef pj_ice_sess_cand remote_cand[_PJ_ICE_MAX_CAND]
    cdef pj_sockaddr      remote_addr[2]
    
    def __init__(self, bool isIncoming, host, storageurl, dns_server, stun_server, turn_server, turn_user, turn_pwd):
        global g
        self.role = [ PJ_ICE_SESS_ROLE_CONTROLLING, PJ_ICE_SESS_ROLE_CONTROLLED ][isIncoming]
        self.host = host
        self.storageurl = storageurl
        cdef pj_str_t    tmpstr
        cdef pj_uint16_t port
        cdef pj_status_t status
        if dns_server:
            #set DNS server
            self.dns_server = self.splitServer(dns_server, 53)
            status = pj_dns_resolver_create(&g.caching_pool.factory, "ice_resolver", 0, g.rtp_timer_heap, g.rtp_ioq, &self.resolver)
            pj_check_status(status)
            pj_cstr(&tmpstr, self.dns_server[0])
            port = self.dns_server[1]
            status = pj_dns_resolver_set_ns(self.resolver, 1, &tmpstr, &port)
            pj_check_status(status)
        pj_ice_strans_cfg_default(&self.cfg)
        self.cfg.resolver = self.resolver
        pj_stun_config_init(&self.cfg.stun_cfg, &g.caching_pool.factory, 0, g.rtp_ioq, g.rtp_timer_heap)
        # STUN
        self.cfg.stun_tp_cnt = 2
        # STUN config RTP
        self.cfg.stun_tp[<int>COMPID_RTP-1].cfg.so_rcvbuf_size = MAXRTPLEN
        self.cfg.stun_tp[<int>COMPID_RTP-1].cfg.so_sndbuf_size = MAXRTPLEN
        self.cfg.stun_tp[<int>COMPID_RTP-1].cfg.max_pkt_size   = MAXRTPLEN
        self.cfg.stun_tp[<int>COMPID_RTP-1].cfg.async_cnt      = MAXASYNC
        self.cfg.stun_tp[<int>COMPID_RTP-1].cfg.qos_type       = PJ_QOS_TYPE_VOICE
        self.cfg.stun_tp[<int>COMPID_RTP-1].max_host_cands = 1    
        status = pj_sockaddr_parse(pj_AF_UNSPEC(), 0, pj_cstr(&tmpstr, self.host), &self.cfg.stun_tp[<int>COMPID_RTP-1].cfg.bound_addr)
        pj_check_status(status)
        self.cfg.stun_tp[<int>COMPID_RTP-1].af = self.cfg.stun_tp[<int>COMPID_RTP-1].cfg.bound_addr.addr.sa_family
        # STUN config RTCP
        self.cfg.stun_tp[<int>COMPID_RTCP-1].cfg.so_rcvbuf_size = MAXRTPLEN
        self.cfg.stun_tp[<int>COMPID_RTCP-1].cfg.so_sndbuf_size = MAXRTPLEN
        self.cfg.stun_tp[<int>COMPID_RTCP-1].cfg.max_pkt_size   = MAXRTPLEN
        self.cfg.stun_tp[<int>COMPID_RTCP-1].cfg.async_cnt      = MAXASYNC
        self.cfg.stun_tp[<int>COMPID_RTCP-1].cfg.qos_type       = PJ_QOS_TYPE_CONTROL
        self.cfg.stun_tp[<int>COMPID_RTCP-1].max_host_cands = 1    
        status = pj_sockaddr_parse(pj_AF_UNSPEC(), 0, pj_cstr(&tmpstr, self.host), &self.cfg.stun_tp[<int>COMPID_RTCP-1].cfg.bound_addr)
        pj_check_status(status)
        self.cfg.stun_tp[<int>COMPID_RTCP-1].af = self.cfg.stun_tp[<int>COMPID_RTCP-1].cfg.bound_addr.addr.sa_family
        # set STUN server config
        if stun_server:
            self.stun_server = self.splitServer(stun_server, PJ_STUN_PORT)
            # RTP
            pj_cstr(&self.cfg.stun_tp[<int>COMPID_RTP-1].server, self.stun_server[0])
            self.cfg.stun_tp[<int>COMPID_RTP-1].port = self.stun_server[1]
            # RTCP
            pj_cstr(&self.cfg.stun_tp[<int>COMPID_RTCP-1].server, self.stun_server[0])
            self.cfg.stun_tp[<int>COMPID_RTCP-1].port = self.stun_server[1]
        # TURN
        # TURN config RTP
        self.cfg.turn_tp[<int>COMPID_RTP-1].cfg.so_rcvbuf_size = MAXRTPLEN
        self.cfg.turn_tp[<int>COMPID_RTP-1].cfg.so_sndbuf_size = MAXRTPLEN
        self.cfg.turn_tp[<int>COMPID_RTP-1].cfg.max_pkt_size   = MAXRTPLEN
        self.cfg.turn_tp[<int>COMPID_RTP-1].cfg.qos_type       = PJ_QOS_TYPE_VOICE
        status = pj_sockaddr_parse(pj_AF_UNSPEC(), 0, pj_cstr(&tmpstr, self.host), &self.cfg.turn_tp[<int>COMPID_RTP-1].cfg.bound_addr)
        pj_check_status(status)
        self.cfg.turn_tp[<int>COMPID_RTP-1].af = self.cfg.turn_tp[<int>COMPID_RTP-1].cfg.bound_addr.addr.sa_family
        # TURN config RTCP
        self.cfg.turn_tp[<int>COMPID_RTCP-1].cfg.so_rcvbuf_size = MAXRTPLEN
        self.cfg.turn_tp[<int>COMPID_RTCP-1].cfg.so_sndbuf_size = MAXRTPLEN
        self.cfg.turn_tp[<int>COMPID_RTCP-1].cfg.max_pkt_size   = MAXRTPLEN
        self.cfg.turn_tp[<int>COMPID_RTCP-1].cfg.qos_type       = PJ_QOS_TYPE_CONTROL
        status = pj_sockaddr_parse(pj_AF_UNSPEC(), 0, pj_cstr(&tmpstr, self.host), &self.cfg.turn_tp[<int>COMPID_RTCP-1].cfg.bound_addr)
        pj_check_status(status)
        self.cfg.turn_tp[<int>COMPID_RTCP-1].af = self.cfg.turn_tp[<int>COMPID_RTCP-1].cfg.bound_addr.addr.sa_family
        # set TURN server config
        if turn_server:
            self.cfg.turn_tp_cnt = 2
            self.turn_server = self.splitServer(turn_server, PJ_STUN_PORT)
            self.turn_user = turn_user
            self.turn_pwd = turn_pwd
            # RTP
            pj_cstr(&self.cfg.turn_tp[<int>COMPID_RTP-1].server, self.turn_server[0])
            self.cfg.turn_tp[<int>COMPID_RTP-1].port = self.turn_server[1]
            self.cfg.turn_tp[<int>COMPID_RTP-1].auth_cred.type = PJ_STUN_AUTH_CRED_STATIC
            pj_cstr(&self.cfg.turn_tp[<int>COMPID_RTP-1].auth_cred.data.static_cred.username, self.turn_user)
            pj_cstr(&self.cfg.turn_tp[<int>COMPID_RTP-1].auth_cred.data.static_cred.data, self.turn_pwd)
            self.cfg.turn_tp[<int>COMPID_RTP-1].auth_cred.data.static_cred.data_type = PJ_STUN_PASSWD_PLAIN
            self.cfg.turn_tp[<int>COMPID_RTP-1].conn_type = PJ_TURN_TP_UDP
            # RTCP
            pj_cstr(&self.cfg.turn_tp[<int>COMPID_RTCP-1].server, self.turn_server[0])
            self.cfg.turn_tp[<int>COMPID_RTCP-1].port = self.turn_server[1]
            self.cfg.turn_tp[<int>COMPID_RTCP-1].auth_cred.type = PJ_STUN_AUTH_CRED_STATIC
            pj_cstr(&self.cfg.turn_tp[<int>COMPID_RTCP-1].auth_cred.data.static_cred.username, self.turn_user)
            pj_cstr(&self.cfg.turn_tp[<int>COMPID_RTCP-1].auth_cred.data.static_cred.data, self.turn_pwd)
            self.cfg.turn_tp[<int>COMPID_RTCP-1].auth_cred.data.static_cred.data_type = PJ_STUN_PASSWD_PLAIN
            self.cfg.turn_tp[<int>COMPID_RTCP-1].conn_type = PJ_TURN_TP_UDP
        cdef pj_ice_strans_cb callbacks
        pj_memset(&callbacks, 0, sizeof(callbacks))
        callbacks.on_rx_data = PJICEStream_on_rx_data
        callbacks.on_ice_complete = PJICEStream_on_ice_complete 
        status = pj_ice_strans_create("icestream", &self.cfg, 2, <void*>self, &callbacks, &self.ice_st)
        pj_check_status(status)
                    
    def __dealloc__(self):
        self.close()
        
    def close(self):
        if self.ice_st:
            pj_ice_strans_destroy(self.ice_st)
            self.ice_st = NULL 
        if self.resolver:
            pj_dns_resolver_destroy(self.resolver, PJ_FALSE)
            self.resolver = NULL
        
    cdef void flush(self) nogil:
        cdef pj_time_val tv
        self.flushing = True
        self.had_packet = True
        while self.had_packet:
            self.had_packet = False
            tv.sec = 0
            tv.msec = 1
            pj_ioqueue_poll(g.rtp_ioq, &tv)
        self.flushing = False
    
    cdef pj_status_t sendData(self, unsigned compid, pj_uint8_t* databuf, pj_size_t datalen) nogil:
        cdef pj_status_t status
        status = pj_ice_strans_sendto(self.ice_st, compid, databuf, datalen, 
                                      <pj_sockaddr_t*>&self.remote_addr[compid-1], 
                                      pj_sockaddr_get_len(<pj_sockaddr_t*>&self.remote_addr[compid-1]))
        if status == PJ_EPENDING:
            clog("icestream", 1, "packet is queued")
        return status
    
    def onLocalId(self, id):
        # to be overwritten
        pass
    
    def onConnected(self):
        # to be overwritten
        pass
    
    def onFailed(self):
        # to be overwritten
        pass
    
    def splitServer(self, name, defaultport):
        t = name.split(':', 1)
        if len(t) > 1:
            return (t[0], int(t[1]))
        else:
            return (t[0], defaultport)
        
    def setRemoteId(self, id):
        if self.remote_id:
            return
        cdef pj_ice_sess_cand *cand = &self.remote_cand[0]
        cdef pj_status_t status
        cdef unsigned i
        cdef pj_str_t ufrag
        cdef pj_str_t pwd
        cdef pj_str_t tmpstr
        try:
            # hold reference to data (for pj strings)
            self.remote_data = data = self.loadConf(id)
            logi.debug("remote offer: %s", data)
            logi.debug("%d candidates (max=%d,pj=%d)", len(data['candidates']), _PJ_ICE_MAX_CAND, PJ_ICE_MAX_CAND)
            pj_cstr(&ufrag, data['ufrag'])
            pj_cstr(&pwd, data['pwd'])
            i = 0
            for c in data['candidates']:
                if i >= _PJ_ICE_MAX_CAND:
                    logi.error("too many candidates: %s", data['candidates'])
                    pj_check_status(PJ_ETOOMANY)
                pj_cstr(&cand[i].foundation, c['foundation'])
                cand[i].prio = c['prio']
                cand[i].comp_id = c['compid']
                cand[i].type = c['type']
                status = pj_sockaddr_parse(pj_AF_UNSPEC(), 0, pj_cstr(&tmpstr, c['addr']), &cand[i].addr)
                pj_check_status(status)
                if c['default']: memcpy(&self.remote_addr[cand[i].comp_id-1], &cand[i].addr, sizeof(pj_sockaddr))
                i += 1
            status = pj_ice_strans_start_ice(self.ice_st, &ufrag, &pwd, i, cand)
            pj_check_status(status)                  
        except Exception as e:
            logi.error("%s", e, exc_info = exc_info())
            self.onFailed()
        self.remote_id = id            
            
    def on_init_done(self):
        cdef pj_status_t status
        try:
            status = pj_ice_strans_init_ice(self.ice_st, self.role, NULL, NULL)
            pj_check_status(status)
            self.storeConf()
            self.onLocalId(self.localid)
        except Exception as e:
            logi.error("%s", e, exc_info = exc_info())
            self.onFailed()            
    
    def conf2dict(self):
        d = {}
        cdef pj_str_t ufrag
        cdef pj_str_t pwd
        pj_ice_strans_get_ufrag_pwd(self.ice_st, &ufrag, &pwd, NULL, NULL);        
        d['ufrag'] = ufrag.ptr[:ufrag.slen] 
        d['pwd'] = pwd.ptr[:pwd.slen]
        d['candidates'] = self.comp2list(COMPID_RTP) + self.comp2list(COMPID_RTCP)
        return d
    
    def comp2list(self, compid_t compid):
        cdef pj_ice_sess_cand cand[_PJ_ICE_MAX_CAND]
        cdef pj_ice_sess_cand def_cand
        cdef unsigned cand_count = _PJ_ICE_MAX_CAND
        cdef pj_status_t status
        status = pj_ice_strans_enum_cands(self.ice_st, compid, &cand_count, cand)
        pj_check_status(status)
        status = pj_ice_strans_get_def_cand(self.ice_st, compid, &def_cand)
        pj_check_status(status)        
        l = []
        cdef int i
        cdef char addrstr[256]
        for i in xrange(cand_count):
            d = {}
            d['foundation'] = cand[i].foundation.ptr[:cand[i].foundation.slen]
            d['prio'] = cand[i].prio
            d['compid'] = cand[i].comp_id
            pj_sockaddr_print(&cand[i].addr, addrstr, sizeof(addrstr), 3)
            d['addr'] = addrstr
            d['default'] = pj_sockaddr_cmp(<pj_sockaddr_t*>&def_cand.addr, <pj_sockaddr_t*>&cand[i].addr) == 0
            d['type'] = cand[i].type
            l.append(d)
        return l
    
    def urlopen(self, request):
        retrycount = 0
        while True:
            try:
                return urllib.request.urlopen(request)
            except Exception as e:
                retrycount += 1
                if retrycount == 2:
                    info = exc_info()
                    logi.error("giving up urlopen after %d retries: %s", retrycount, info[1], exc_info=info )
                    raise e
    
    def storeConf(self):
        data = json.dumps(self.conf2dict()).encode("utf8")
        headers = { 'Content-Type': 'application/json'  }
        if self.localid:
            headers['X-icestorage-token'] = self.token
            request = PostRequest(self.storageurl + '/' + self.localid, data, headers)
        else:
            request = PutRequest(self.storageurl, data, headers)
        response = self.urlopen(request)
        data = json.loads(response.read().decode("utf8"))
        if not self.localid:
            self.localid = data['id']
            self.token = data['token']
        return data

    def loadConf(self, id):
        request = urllib.request.Request(self.storageurl + '/' + id)
        response = self.urlopen(request)
        data = response.read().decode("utf8")
        return json.loads(data)

    # callbacks
    
    cdef void on_rx_data(self, unsigned comp_id, void* pkt, pj_size_t size, const pj_sockaddr_t* src_addr, unsigned src_addr_len) nogil:
        # to be overwritten
        pass
 
    cdef void _on_rx_data(self, unsigned comp_id, void* pkt, pj_size_t size, const pj_sockaddr_t* src_addr, unsigned src_addr_len) nogil:
        self.had_packet = True
        if self.flushing: return
        self.on_rx_data(comp_id, pkt, size, src_addr, src_addr_len)
 
    cdef void on_ice_complete(self, pj_ice_strans_op op, pj_status_t status) with gil:
        logi.debug("on_ice_complete(): op=%d, status=%s", op, status2str(status))
        if op == PJ_ICE_STRANS_OP_INIT:
            if status != PJ_SUCCESS:
                logi.error("ice init failed: status=%s", status2str(status))
                self.onFailed()
                return
            self.on_init_done()
        elif op == PJ_ICE_STRANS_OP_NEGOTIATION:
            if status != PJ_SUCCESS:
                logi.error("ice negotiate failed: status=%s", status2str(status))
                self.onFailed()
                return
            self.onConnected()
        elif op == PJ_ICE_STRANS_OP_KEEP_ALIVE:
            pass # do nothing    
        elif op == PJ_ICE_STRANS_OP_ADDR_CHANGE:
            pass # do nothing     

# callback glue 

cdef void PJICEStream_on_rx_data(pj_ice_strans* ice_st, unsigned comp_id, void* pkt, pj_size_t size, const pj_sockaddr_t* src_addr, unsigned src_addr_len) nogil:
    (<PJICEStream>pj_ice_strans_get_user_data(ice_st))._on_rx_data(comp_id, pkt, size, src_addr, src_addr_len)
 
cdef void PJICEStream_on_ice_complete(pj_ice_strans* ice_st, pj_ice_strans_op op, pj_status_t status) nogil:
    (<PJICEStream>pj_ice_strans_get_user_data(ice_st)).on_ice_complete(op, status)


