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
#
# PJLIB
#
cdef extern from "pjlib.h":

    cdef int EADDRINUSE

    cdef int PJ_SUCCESS
    cdef int PJ_TRUE
    cdef int PJ_FALSE
    
    cdef int PJ_ENOMEM
    cdef int PJ_EPENDING
    cdef int PJ_ETOOMANY
    
    ctypedef int            pj_int32_t
    ctypedef unsigned int   pj_uint32_t
    ctypedef short          pj_int16_t
    ctypedef unsigned short pj_uint16_t
    ctypedef signed char    pj_int8_t
    ctypedef unsigned char  pj_uint8_t
    ctypedef size_t         pj_size_t

    ctypedef int     pj_bool_t
    ctypedef struct  pj_grp_lock_t:
        pass
    ctypedef void    pj_sockaddr_t
    ctypedef ssize_t pj_ssize_t
    ctypedef int     pj_status_t
    ctypedef struct  pj_str_t:
        char*      ptr 
        pj_ssize_t slen
    ctypedef struct  pj_time_val:
        long sec
        long msec
    
    cdef pj_status_t pj_init() nogil
    cdef void        pj_shutdown() nogil
    
    # errno
    cdef pj_str_t    pj_strerror(pj_status_t statcode, char* buf, pj_size_t bufsize) nogil
    cdef pj_status_t PJ_STATUS_FROM_OS(pj_status_t status) nogil

    # Logging facility
    ctypedef void (*pj_log_func)(int level, const char *data, int len)
    
    cdef void pj_log_set_level(int level) nogil
             
    # Linked Lists
    ctypedef struct pj_list:
        void* prev
        void* next
    
    # Locks
    ctypedef struct pj_lock_t:
        pass
    ctypedef struct pj_grp_lock_t:
        pass
    ctypedef struct pj_grp_lock_config:
        unsigned flags
    
    cdef pj_status_t pj_lock_acquire(pj_lock_t* lock) nogil         
    cdef pj_status_t pj_lock_create_simple_mutex(pj_pool_t* pool, const char* name, pj_lock_t** lock) nogil 
    cdef pj_status_t pj_lock_create_recursive_mutex(pj_pool_t* pool, const char* name, pj_lock_t** lock) nogil
    cdef pj_status_t pj_lock_destroy(pj_lock_t* lock) nogil
    cdef pj_status_t pj_lock_release(pj_lock_t* lock) nogil

    cdef void        pj_grp_lock_config_default(pj_grp_lock_config* cfg) nogil
    cdef pj_status_t pj_grp_lock_create(pj_pool_t* pool, const pj_grp_lock_config* cfg, pj_grp_lock_t** p_grp_lock) nogil
    cdef pj_status_t pj_grp_lock_create_w_handler(pj_pool_t* pool, const pj_grp_lock_config* cfg, void* member, void(*handler)(void *member), pj_grp_lock_t** p_grp_lock) nogil 
    cdef pj_status_t pj_grp_lock_destroy(pj_grp_lock_t* grp_lock) nogil
    cdef pj_status_t pj_grp_lock_replace(pj_grp_lock_t* old_lock, pj_grp_lock_t* new_lock) nogil 
    cdef pj_status_t pj_grp_lock_acquire(pj_grp_lock_t* grp_lock) nogil 
    cdef pj_status_t pj_grp_lock_tryacquire(pj_grp_lock_t *grp_lock) nogil 
    cdef pj_status_t pj_grp_lock_release(pj_grp_lock_t* grp_lock) nogil 
    cdef pj_status_t pj_grp_lock_add_handler(pj_grp_lock_t* grp_lock, pj_pool_t* pool, void* member, void(*handler)(void *member)) nogil 
    cdef pj_status_t pj_grp_lock_del_handler(pj_grp_lock_t* grp_lock, void* member, void(*handler)(void *member)) nogil
    cdef pj_status_t pj_grp_lock_add_ref(pj_grp_lock_t* grp_lock) nogil
    cdef pj_status_t pj_grp_lock_dec_ref(pj_grp_lock_t* grp_lock) nogil
    cdef int         pj_grp_lock_get_ref(pj_grp_lock_t* grp_lock) nogil
    cdef void        pj_grp_lock_dump (pj_grp_lock_t* grp_lock) nogil
    cdef pj_status_t pj_grp_lock_chain_lock(pj_grp_lock_t* grp_lock, pj_lock_t* ext_lock, int pos) nogil 
    cdef pj_status_t pj_grp_lock_unchain_lock(pj_grp_lock_t* grp_lock, pj_lock_t* ext_lock) nogil
              
    # Fast memory pool
    ctypedef struct pj_pool_factory:
        pass
    ctypedef struct pj_pool_factory_policy:
        pass
    ctypedef struct pj_pool_t: 
        pass
    ctypedef void (*pj_pool_callback)(pj_pool_t* pool, pj_size_t size)
    
    cdef pj_pool_t* pj_pool_create(pj_pool_factory*  factory, 
                                   const char*       name,
                                   pj_size_t         initial_size,
                                   pj_size_t         increment_size,
                                   pj_pool_callback  callback) nogil
    cdef void       pj_pool_release(pj_pool_t* pool) nogil
    cdef void*      pj_pool_zalloc(pj_pool_t* pool, pj_size_t size) nogil         

      

    ctypedef struct pj_caching_pool:
        pj_pool_factory factory
        pj_size_t       capacity 
        pj_size_t       max_capacity 
        pj_size_t       used_count 
        pj_size_t       used_size 
        pj_size_t       peak_used_size 
        pj_list         free_list [16] 
        pj_list         used_list 
        char            pool_buf [512]
        pj_lock_t*      lock
    
    cdef void pj_caching_pool_init (pj_caching_pool *ch_pool, const pj_pool_factory_policy *policy, pj_size_t max_capacity) nogil
    cdef void pj_caching_pool_destroy(pj_caching_pool *ch_pool) nogil
    
    # Strings
    cdef const pj_str_t* pj_cstr(pj_str_t* str, const char* s) nogil
    cdef void*           pj_memset(void* dst, int c, pj_size_t size) nogil
    cdef pj_str_t*       pj_strdup2(pj_pool_t* pool,  pj_str_t* dst, const char* src) nogil     
 
    # Threads
    ctypedef int (*pj_thread_proc)(void *arg) 
    ctypedef long   pj_thread_desc[64]
    ctypedef struct pj_thread_t:
        pass
    
    cdef pj_status_t pj_thread_create(pj_pool_t*     pool,
                                      const char*    thread_name,
                                      pj_thread_proc proc,
                                      void*          arg,
                                      pj_size_t      stack_size,
                                      unsigned       flags,
                                      pj_thread_t**  thread) nogil
    cdef pj_status_t  pj_thread_join(pj_thread_t* thread) nogil
    cdef pj_status_t  pj_thread_destroy(pj_thread_t* thread) nogil
    cdef const char*  pj_thread_get_name(pj_thread_t* thread) nogil
    cdef pj_status_t  pj_thread_register(const char* thread_name, pj_thread_desc desc, pj_thread_t** thread) nogil 
    cdef pj_status_t  pj_thread_sleep(unsigned msec) nogil
    cdef pj_thread_t* pj_thread_this() nogil
    
    # Events
    ctypedef struct pj_event_t:
        pass
    
    cdef pj_status_t pj_event_create(pj_pool_t* pool, const char* name, pj_bool_t manual_reset, pj_bool_t initial, pj_event_t** event) nogil
    cdef pj_status_t pj_event_wait(pj_event_t* event) nogil
    cdef pj_status_t pj_event_trywait(pj_event_t* event) nogil
    cdef pj_status_t pj_event_set (pj_event_t* event) nogil
    cdef pj_status_t pj_event_pulse(pj_event_t* event) nogil
    cdef pj_status_t pj_event_reset(pj_event_t* event) nogil
    cdef pj_status_t pj_event_destroy(pj_event_t* event) nogil
    
    # Time
    cdef pj_status_t pj_gettimeofday(pj_time_val* tv) nogil
 
    # Timer heap
    ctypedef int pj_timer_id_t
    ctypedef struct pj_timer_entry
    ctypedef void pj_timer_heap_callback(pj_timer_heap_t* ht, pj_timer_entry* entry)
    ctypedef struct pj_timer_heap_t:
        pass
    ctypedef struct pj_timer_entry:
        void*                   user_data 
        int                     id
        pj_timer_heap_callback* cb 
        pj_timer_id_t           _timer_id 
        pj_time_val             _timer_value
        pj_grp_lock_t*          _grp_lock
        
    cdef pj_bool_t       pj_timer_entry_running(pj_timer_entry* entry) nogil 
    cdef int             pj_timer_heap_cancel(pj_timer_heap_t* ht, pj_timer_entry* entry) nogil         
    cdef pj_status_t     pj_timer_heap_create(pj_pool_t* pool, pj_size_t count, pj_timer_heap_t** ht) nogil        
    cdef pj_size_t       pj_timer_heap_count(pj_timer_heap_t* ht) nogil
    cdef void            pj_timer_heap_destroy(pj_timer_heap_t* ht) nogil     
    cdef void            pj_timer_heap_dump(pj_timer_heap_t* ht) nogil
    cdef pj_timer_entry* pj_timer_entry_init(pj_timer_entry* entry, int id, void* user_data,  pj_timer_heap_callback* cb) nogil
    cdef unsigned        pj_timer_heap_poll(pj_timer_heap_t* ht, pj_time_val* next_delay) nogil     
    cdef pj_status_t     pj_timer_heap_schedule(pj_timer_heap_t* ht, pj_timer_entry* entry, const pj_time_val* delay) nogil
    cdef void            pj_timer_heap_set_lock(pj_timer_heap_t* ht, pj_lock_t* lock, pj_bool_t auto_del) nogil
             
    # QoS
    ctypedef enum pj_qos_type:
        PJ_QOS_TYPE_BEST_EFFORT,     
        PJ_QOS_TYPE_BACKGROUND,     
        PJ_QOS_TYPE_VIDEO,     
        PJ_QOS_TYPE_VOICE,     
        PJ_QOS_TYPE_CONTROL,     
        PJ_QOS_TYPE_SIGNALLING     

    ctypedef enum pj_qos_wmm_prio:
        PJ_QOS_WMM_PRIO_BULK_EFFORT,     
        PJ_QOS_WMM_PRIO_BULK,     
        PJ_QOS_WMM_PRIO_VIDEO,     
        PJ_QOS_WMM_PRIO_VOICE     

    ctypedef struct pj_qos_params:
        pj_uint8_t      flags
        pj_uint8_t      dscp_val 
        pj_uint8_t      so_prio 
        pj_qos_wmm_prio wmm_prio
 
    # IOQueue    
    cdef int PJ_IOQUEUE_ALWAYS_ASYNC
    cdef int PJ_IOQUEUE_NO_ASYNC
    
    ctypedef struct pj_ioqueue_op_key_t:
        void* internal__ [32]
        void* activesock_data
        void* user_data
        
    ctypedef struct pj_ioqueue_t: 
        pass
    
    cdef pj_status_t pj_ioqueue_create(pj_pool_t* pool, pj_size_t max_fd, pj_ioqueue_t** ioqueue) nogil
    cdef pj_status_t pj_ioqueue_destroy(pj_ioqueue_t* ioque) nogil
    cdef void        pj_ioqueue_op_key_init(pj_ioqueue_op_key_t* op_key, pj_size_t size) nogil
    cdef int         pj_ioqueue_poll(pj_ioqueue_t* ioque, const pj_time_val* timeout) nogil
    cdef pj_status_t pj_ioqueue_set_lock(pj_ioqueue_t* ioque, pj_lock_t* lock, pj_bool_t auto_delete) nogil
        
    # Sockets
    cdef int PJ_INVALID_SOCKET
    
    ctypedef struct pj_addr_hdr:
        pj_uint16_t sa_family
        
    ctypedef struct pj_in_addr:
        pj_uint32_t s_addr
        
    ctypedef struct pj_in6_addr:
        pj_uint8_t  s6_addr[16]
        pj_uint32_t u6_addr32[4]
 
    ctypedef struct pj_sockaddr_in:
        pj_uint16_t sin_family
        pj_uint16_t sin_port
        pj_in_addr  sin_addr
        char        sin_zero[8]
        
    ctypedef struct pj_sockaddr_in6:
        pj_uint16_t sin6_family
        pj_uint16_t sin6_port 
        pj_uint32_t sin6_flowinfo
        pj_in6_addr sin6_addr 
        pj_uint32_t sin6_scope_id
     
    ctypedef struct pj_sockaddr:
        pj_addr_hdr     addr 
        pj_sockaddr_in  ipv4
        pj_sockaddr_in6 ipv6
        
    DEF _PJ_MAX_SOCKOPT_PARAMS = 4
    
    ctypedef struct sockopt_options:
        int   level
        int   optname
        void* optval
        int   optlen
    
    ctypedef struct pj_sockopt_params:
        unsigned        cnt
        sockopt_options options[_PJ_MAX_SOCKOPT_PARAMS]

    ctypedef long pj_sock_t
    
    cdef int pj_AF_UNSPEC() nogil
    cdef int pj_AF_INET() nogil
    cdef int pj_AF_INET6() nogil
    
    cdef int pj_SOCK_DGRAM() nogil
    
    cdef pj_uint16_t pj_ntohs (pj_uint16_t netshort) nogil
    cdef pj_uint16_t pj_htons (pj_uint16_t hostshort) nogil
    cdef pj_uint32_t pj_ntohl (pj_uint32_t netlong) nogil
    cdef pj_uint32_t pj_htonl (pj_uint32_t hostlong) nogil
    cdef int         pj_sockaddr_cmp(const pj_sockaddr_t* addr1, const pj_sockaddr_t* addr2) nogil
    cdef unsigned    pj_sockaddr_get_len(const pj_sockaddr_t* addr) nogil     
    cdef pj_uint16_t pj_sockaddr_get_port(const pj_sockaddr_t* addr) nogil     
    cdef pj_status_t pj_sockaddr_init(int af, pj_sockaddr* addr, const pj_str_t* cp, pj_uint16_t port) nogil 
    cdef pj_status_t pj_sockaddr_parse(int af, unsigned options, const pj_str_t* str, pj_sockaddr* addr) nogil
    cdef char*       pj_sockaddr_print(const pj_sockaddr_t* addr, char* buf, int size, unsigned flags) nogil
    cdef pj_status_t pj_sockaddr_set_port(pj_sockaddr* addr, pj_uint16_t hostport) nogil    
    cdef pj_status_t pj_sock_bind (pj_sock_t sockfd, const pj_sockaddr_t* my_addr, int addrlen) nogil             
    cdef pj_status_t pj_sock_close (pj_sock_t sockfd) nogil 
    cdef pj_status_t pj_sock_getsockname(pj_sock_t sockfd, pj_sockaddr_t* addr, int* namelen) nogil
    cdef pj_status_t pj_sock_recvfrom(pj_sock_t sockfd, void* buf, pj_ssize_t* len, unsigned flags, pj_sockaddr_t* _from, int* fromlen) nogil
    cdef pj_status_t pj_sock_set_qos_type(pj_sock_t sock, pj_qos_type type) nogil 
    cdef pj_status_t pj_sock_socket(int family, int type, int protocol, pj_sock_t* sock) nogil
 
    # ActiveSock
    ctypedef struct pj_activesock_t:
        pass
    ctypedef struct pj_activesock_cb:
        pj_bool_t (*on_data_read)(pj_activesock_t* asock, void* data, pj_size_t size, pj_status_t status, pj_size_t* remainder)
        pj_bool_t (*on_data_recvfrom)(pj_activesock_t* asock, void* data, pj_size_t size, const pj_sockaddr_t* src_addr, int addr_len, pj_status_t status)
        pj_bool_t (*on_data_sent)(pj_activesock_t* asock, pj_ioqueue_op_key_t* send_key, pj_ssize_t sent)
        pj_bool_t (*on_accept_complete)(pj_activesock_t* asock, pj_sock_t newsock, const pj_sockaddr_t* src_addr, int src_addr_len)
        pj_bool_t (*on_accept_complete2)(pj_activesock_t* asock, pj_sock_t newsock, const pj_sockaddr_t* src_addr, int src_addr_len, pj_status_t status) 
        pj_bool_t (*on_connect_complete)(pj_activesock_t* asock, pj_status_t status)
    ctypedef struct pj_activesock_cfg:
        pj_grp_lock_t* grp_lock
        unsigned       async_cnt
        int            concurrency     
        pj_bool_t      whole_data
        
    cdef void        pj_activesock_cfg_default(pj_activesock_cfg *cfg) nogil
    cdef pj_status_t pj_activesock_create(pj_pool_t* pool, pj_sock_t sock, int sock_type, const pj_activesock_cfg* opt, pj_ioqueue_t* ioqueue, const pj_activesock_cb* cb, void* user_data, pj_activesock_t** p_asock) nogil
    cdef pj_status_t pj_activesock_create_udp(pj_pool_t* pool, const pj_sockaddr* addr, const pj_activesock_cfg* opt, pj_ioqueue_t* ioqueue, const pj_activesock_cb* cb, void* user_data, pj_activesock_t** p_asock, pj_sockaddr* bound_addr) nogil
    cdef pj_status_t pj_activesock_close(pj_activesock_t* asock) nogil
    cdef pj_status_t pj_activesock_set_user_data(pj_activesock_t* asock, void* user_data) nogil
    cdef void*       pj_activesock_get_user_data(pj_activesock_t* asock) nogil
    cdef pj_status_t pj_activesock_start_read(pj_activesock_t* asock, pj_pool_t* pool, unsigned buff_size, pj_uint32_t flags) nogil
    cdef pj_status_t pj_activesock_start_read2(pj_activesock_t* asock, pj_pool_t* pool, unsigned buff_size, void* readbuf[], pj_uint32_t flags) nogil
    cdef pj_status_t pj_activesock_start_recvfrom(pj_activesock_t* asock, pj_pool_t* pool, unsigned buff_size, pj_uint32_t flags) nogil
    cdef pj_status_t pj_activesock_start_recvfrom2(pj_activesock_t* asock, pj_pool_t* pool, unsigned buff_size, void* readbuf[], pj_uint32_t flags) nogil
    cdef pj_status_t pj_activesock_send(pj_activesock_t* asock, pj_ioqueue_op_key_t* send_key, const void* data, pj_ssize_t* size, unsigned flags) nogil
    cdef pj_status_t pj_activesock_sendto(pj_activesock_t* asock, pj_ioqueue_op_key_t* send_key, const void* data, pj_ssize_t* size, unsigned flags, const pj_sockaddr_t* addr, int addr_len) nogil
    cdef pj_status_t pj_activesock_start_accept(pj_activesock_t* asock, pj_pool_t* pool) nogil
    cdef pj_status_t pj_activesock_start_connect(pj_activesock_t* asock, pj_pool_t* pool, const pj_sockaddr_t* remaddr, int addr_len) nogil
    
    # ssl
    ctypedef struct pj_ssl_sock_t:
        pass
    
    ctypedef pj_str_t pj_ssl_cert_buffer
    
    ctypedef enum pj_ssl_cipher:
        PJ_TLS_UNKNOWN_CIPHER,
        PJ_TLS_NULL_WITH_NULL_NULL,
        PJ_TLS_RSA_WITH_NULL_MD5,
        PJ_TLS_RSA_WITH_NULL_SHA,
        PJ_TLS_RSA_WITH_NULL_SHA256,
        PJ_TLS_RSA_WITH_RC4_128_MD5,
        PJ_TLS_RSA_WITH_RC4_128_SHA,
        PJ_TLS_RSA_WITH_3DES_EDE_CBC_SHA,
        PJ_TLS_RSA_WITH_AES_128_CBC_SHA,
        PJ_TLS_RSA_WITH_AES_256_CBC_SHA,
        PJ_TLS_RSA_WITH_AES_128_CBC_SHA256,
        PJ_TLS_RSA_WITH_AES_256_CBC_SHA256,
        PJ_TLS_DH_DSS_WITH_3DES_EDE_CBC_SHA,
        PJ_TLS_DH_RSA_WITH_3DES_EDE_CBC_SHA,
        PJ_TLS_DHE_DSS_WITH_3DES_EDE_CBC_SHA,
        PJ_TLS_DHE_RSA_WITH_3DES_EDE_CBC_SHA,
        PJ_TLS_DH_DSS_WITH_AES_128_CBC_SHA,
        PJ_TLS_DH_RSA_WITH_AES_128_CBC_SHA,
        PJ_TLS_DHE_DSS_WITH_AES_128_CBC_SHA,
        PJ_TLS_DHE_RSA_WITH_AES_128_CBC_SHA,
        PJ_TLS_DH_DSS_WITH_AES_256_CBC_SHA,
        PJ_TLS_DH_RSA_WITH_AES_256_CBC_SHA,
        PJ_TLS_DHE_DSS_WITH_AES_256_CBC_SHA,
        PJ_TLS_DHE_RSA_WITH_AES_256_CBC_SHA,
        PJ_TLS_DH_DSS_WITH_AES_128_CBC_SHA256,
        PJ_TLS_DH_RSA_WITH_AES_128_CBC_SHA256,
        PJ_TLS_DHE_DSS_WITH_AES_128_CBC_SHA256,
        PJ_TLS_DHE_RSA_WITH_AES_128_CBC_SHA256,
        PJ_TLS_DH_DSS_WITH_AES_256_CBC_SHA256,
        PJ_TLS_DH_RSA_WITH_AES_256_CBC_SHA256,
        PJ_TLS_DHE_DSS_WITH_AES_256_CBC_SHA256,
        PJ_TLS_DHE_RSA_WITH_AES_256_CBC_SHA256,
        PJ_TLS_DH_anon_WITH_RC4_128_MD5,
        PJ_TLS_DH_anon_WITH_3DES_EDE_CBC_SHA,
        PJ_TLS_DH_anon_WITH_AES_128_CBC_SHA,
        PJ_TLS_DH_anon_WITH_AES_256_CBC_SHA,
        PJ_TLS_DH_anon_WITH_AES_128_CBC_SHA256,
        PJ_TLS_DH_anon_WITH_AES_256_CBC_SHA256,
        # TLS (deprecated) 
        PJ_TLS_RSA_EXPORT_WITH_RC4_40_MD5,
        PJ_TLS_RSA_EXPORT_WITH_RC2_CBC_40_MD5,
        PJ_TLS_RSA_WITH_IDEA_CBC_SHA,
        PJ_TLS_RSA_EXPORT_WITH_DES40_CBC_SHA,
        PJ_TLS_RSA_WITH_DES_CBC_SHA,
        PJ_TLS_DH_DSS_EXPORT_WITH_DES40_CBC_SHA,
        PJ_TLS_DH_DSS_WITH_DES_CBC_SHA,
        PJ_TLS_DH_RSA_EXPORT_WITH_DES40_CBC_SHA,
        PJ_TLS_DH_RSA_WITH_DES_CBC_SHA,
        PJ_TLS_DHE_DSS_EXPORT_WITH_DES40_CBC_SHA,
        PJ_TLS_DHE_DSS_WITH_DES_CBC_SHA,
        PJ_TLS_DHE_RSA_EXPORT_WITH_DES40_CBC_SHA,
        PJ_TLS_DHE_RSA_WITH_DES_CBC_SHA,
        PJ_TLS_DH_anon_EXPORT_WITH_RC4_40_MD5,
        PJ_TLS_DH_anon_EXPORT_WITH_DES40_CBC_SHA,
        PJ_TLS_DH_anon_WITH_DES_CBC_SHA,
        # SSLv3 
        PJ_SSL_FORTEZZA_KEA_WITH_NULL_SHA,
        PJ_SSL_FORTEZZA_KEA_WITH_FORTEZZA_CBC_SHA,
        PJ_SSL_FORTEZZA_KEA_WITH_RC4_128_SHA,
        # SSLv2 
        PJ_SSL_CK_RC4_128_WITH_MD5,
        PJ_SSL_CK_RC4_128_EXPORT40_WITH_MD5,
        PJ_SSL_CK_RC2_128_CBC_WITH_MD5,
        PJ_SSL_CK_RC2_128_CBC_EXPORT40_WITH_MD5,
        PJ_SSL_CK_IDEA_128_CBC_WITH_MD5,
        PJ_SSL_CK_DES_64_CBC_WITH_MD5,
        PJ_SSL_CK_DES_192_EDE3_CBC_WITH_MD5

    ctypedef enum pj_ssl_curve:
        PJ_TLS_UNKNOWN_CURVE,
        PJ_TLS_CURVE_SECT163K1,
        PJ_TLS_CURVE_SECT163R1,
        PJ_TLS_CURVE_SECT163R2,
        PJ_TLS_CURVE_SECT193R1,
        PJ_TLS_CURVE_SECT193R2,
        PJ_TLS_CURVE_SECT233K1,
        PJ_TLS_CURVE_SECT233R1,
        PJ_TLS_CURVE_SECT239K1,
        PJ_TLS_CURVE_SECT283K1,
        PJ_TLS_CURVE_SECT283R1,
        PJ_TLS_CURVE_SECT409K1,
        PJ_TLS_CURVE_SECT409R1,
        PJ_TLS_CURVE_SECT571K1,
        PJ_TLS_CURVE_SECT571R1,
        PJ_TLS_CURVE_SECP160K1,
        PJ_TLS_CURVE_SECP160R1,
        PJ_TLS_CURVE_SECP160R2,
        PJ_TLS_CURVE_SECP192K1,
        PJ_TLS_CURVE_SECP192R1,
        PJ_TLS_CURVE_SECP224K1,
        PJ_TLS_CURVE_SECP224R1,
        PJ_TLS_CURVE_SECP256K1,
        PJ_TLS_CURVE_SECP256R1,
        PJ_TLS_CURVE_SECP384R1,
        PJ_TLS_CURVE_SECP521R1,
        PJ_TLS_CURVE_BRAINPOOLP256R1,
        PJ_TLS_CURVE_BRAINPOOLP384R1,
        PJ_TLS_CURVE_BRAINPOOLP512R1,
        PJ_TLS_CURVE_ARBITRARY_EXPLICIT_PRIME_CURVES,
        PJ_TLS_CURVE_ARBITRARY_EXPLICIT_CHAR2_CURVES
    
    ctypedef enum pj_ssl_entropy_t:
        PJ_SSL_ENTROPY_NONE,
        PJ_SSL_ENTROPY_EGD,
        PJ_SSL_ENTROPY_RANDOM,
        PJ_SSL_ENTROPY_URANDOM,
        PJ_SSL_ENTROPY_FILE,
        PJ_SSL_ENTROPY_UNKNOWN

    ctypedef struct pj_ssl_sock_cb:
        pj_bool_t (*on_data_read)(pj_ssl_sock_t *ssock, void *data, pj_size_t size, pj_status_t status, pj_size_t *remainder)
        pj_bool_t (*on_data_recvfrom)(pj_ssl_sock_t *ssock, void *data, pj_size_t size, const pj_sockaddr_t *src_addr, int addr_len, pj_status_t status)
        pj_bool_t (*on_data_sent)(pj_ssl_sock_t *ssock, pj_ioqueue_op_key_t *send_key, pj_ssize_t sent)
        pj_bool_t (*on_accept_complete)(pj_ssl_sock_t *ssock, pj_ssl_sock_t *newsock, const pj_sockaddr_t *src_addr, int src_addr_len)
        pj_bool_t (*on_accept_complete2)(pj_ssl_sock_t *ssock, pj_ssl_sock_t *newsock, const pj_sockaddr_t *src_addr, int src_addr_len, pj_status_t status)
        pj_bool_t (*on_connect_complete)(pj_ssl_sock_t *ssock, pj_status_t status)
    
    ctypedef struct pj_ssl_sock_param:
        pj_grp_lock_t*    grp_lock
        int               sock_af
        int               sock_type
        pj_ioqueue_t*     ioqueue
        pj_timer_heap_t*  timer_heap
        pj_ssl_sock_cb    cb
        void*             user_data
        pj_uint32_t       proto
        unsigned          async_cnt
        int               concurrency
        pj_bool_t         whole_data
        pj_size_t         send_buffer_size
        pj_size_t         read_buffer_size
        unsigned          ciphers_num
        pj_ssl_cipher*    ciphers
        unsigned          curves_num
        pj_ssl_curve*     curves
        pj_str_t          sigalgs
        pj_ssl_entropy_t  entropy_type
        pj_str_t          entropy_path
        pj_time_val       timeout
        pj_bool_t         verify_peer
        pj_bool_t         require_client_cert
        pj_str_t          server_name
        pj_bool_t         reuse_addr
        pj_qos_type       qos_type
        pj_qos_params     qos_params
        pj_bool_t         qos_ignore_error
        pj_sockopt_params sockopt_params
        pj_bool_t         sockopt_ignore_error
        
#
# PJLIB-UTIL
#
cdef extern from "pjlib-util.h":

    cdef pj_status_t pjlib_util_init() nogil

    # DNS
    ctypedef struct pj_dns_resolver:
        pass

    cdef pj_status_t pj_dns_resolver_create(pj_pool_factory* pf, const char* name, unsigned options, pj_timer_heap_t* timer, pj_ioqueue_t* ioqueue, pj_dns_resolver** p_resolver) nogil
    cdef pj_status_t pj_dns_resolver_destroy(pj_dns_resolver* resolver, pj_bool_t notify) nogil
    cdef pj_status_t pj_dns_resolver_set_ns(pj_dns_resolver* resolver, unsigned count, const pj_str_t servers[], const pj_uint16_t ports[]) nogil
     
#
# PJNATH
#
cdef extern from "pjnath.h":

    cdef pj_status_t pjnath_init() nogil
    
    cdef int PJ_ICE_MAX_CAND
    cdef int PJ_ICE_ST_MAX_CAND
    
    #STUN
    cdef int PJ_STUN_PORT
    
    ctypedef struct pj_stun_config:
        pj_pool_factory* pf
        pj_ioqueue_t*    ioqueue 
        pj_timer_heap_t* timer_heap
        unsigned         options 
        unsigned         rto_msec    
        unsigned         res_cache_msec
        pj_str_t         software_name

    cdef void pj_stun_config_init(pj_stun_config* cfg, pj_pool_factory* factory, unsigned options, pj_ioqueue_t* ioqueue, pj_timer_heap_t* timer_heap)
    
    ctypedef struct pj_stun_sock_cfg:
        pj_grp_lock_t* grp_lock
        unsigned       max_pkt_size
        unsigned       async_cnt
        pj_sockaddr    bound_addr
        pj_uint16_t    port_range
        int            ka_interval
        pj_qos_type    qos_type
        pj_qos_params  qos_params
        pj_bool_t      qos_ignore_error
        unsigned       so_rcvbuf_size
        unsigned       so_sndbuf_size
     
    ctypedef enum pj_stun_passwd_type:
        PJ_STUN_PASSWD_PLAIN,     
        PJ_STUN_PASSWD_HASHED
        
    ctypedef struct pj_stun_static_cred:
        pj_str_t            realm
        pj_str_t            username
        pj_stun_passwd_type data_type
        pj_str_t            data
        pj_str_t            nonce
        
    ctypedef struct pj_stun_msg:
        pass
        
    ctypedef struct pj_stun_dyn_cred:
        void*       user_data
        pj_status_t (*get_auth)(void* user_data, pj_pool_t* pool, pj_str_t* realm, pj_str_t* nonce)
        pj_status_t (*get_cred)(const pj_stun_msg* msg, void* user_data, 
                                pj_pool_t* pool, pj_str_t* realm, pj_str_t* username, 
                                pj_str_t* nonce, pj_stun_passwd_type* data_type, pj_str_t* data)
        pj_status_t (*get_password)(const pj_stun_msg* msg, void* user_data, const pj_str_t* realm, 
                                    const pj_str_t* username, pj_pool_t* pool, 
                                    pj_stun_passwd_type* data_type, pj_str_t* data)
 
        pj_bool_t  (*verify_nonce)(const pj_stun_msg* msg, void* user_data, const pj_str_t* realm, 
                                   const pj_str_t* username, const pj_str_t* nonce)
        
    ctypedef enum pj_stun_auth_cred_type:
        PJ_STUN_AUTH_CRED_STATIC,     
        PJ_STUN_AUTH_CRED_DYNAMIC
 
    ctypedef struct pj_stun_auth_cred_union:
        pj_stun_static_cred static_cred
        pj_stun_dyn_cred    dyn_cred
     
    ctypedef struct pj_stun_auth_cred:
        pj_stun_auth_cred_type  type
        pj_stun_auth_cred_union data
        
    #TURN
    ctypedef enum pj_turn_tp_type:
        PJ_TURN_TP_UDP,     
        PJ_TURN_TP_TCP,     
        PJ_TURN_TP_TLS     

    ctypedef struct pj_turn_alloc_param:
        int             bandwidth
        int             lifetime
        int             ka_interval 
        int             af
        pj_turn_tp_type peer_conn_type
 
    ctypedef struct pj_turn_sock_tls_cfg:
        pj_str_t           ca_list_file
        pj_str_t           ca_list_path
        pj_str_t           cert_file
        pj_str_t           privkey_file
        pj_ssl_cert_buffer ca_buf
        pj_ssl_cert_buffer cert_buf
        pj_ssl_cert_buffer privkey_buf
        pj_str_t           password
        pj_ssl_sock_param  ssock_param

    ctypedef struct pj_turn_sock_cfg:
        pj_grp_lock_t*       grp_lock
        unsigned             max_pkt_size
        pj_qos_type          qos_type 
        pj_qos_params        qos_params 
        pj_bool_t            qos_ignore_error 
        pj_sockaddr          bound_addr 
        pj_uint16_t          port_range 
        unsigned             so_rcvbuf_size 
        unsigned             so_sndbuf_size
        pj_turn_sock_tls_cfg tls_cfg

    #ICE
    ctypedef enum pj_ice_cand_type:
        PJ_ICE_CAND_TYPE_HOST,     
        PJ_ICE_CAND_TYPE_SRFLX,     
        PJ_ICE_CAND_TYPE_PRFLX,     
        PJ_ICE_CAND_TYPE_RELAYED,     
        PJ_ICE_CAND_TYPE_MAX
        
    ctypedef struct pj_ice_sess_cand:
        pj_ice_cand_type type
        pj_status_t      status 
        pj_uint8_t       comp_id
        pj_uint8_t       transport_id
        pj_uint16_t      local_pref
        pj_str_t         foundation
        pj_uint32_t      prio
        pj_sockaddr      addr
        pj_sockaddr      base_addr 
        pj_sockaddr      rel_addr
          
    ctypedef struct pj_ice_sess_options:
        pj_bool_t aggressive
        unsigned  nominated_check_delay
        int       controlled_agent_want_nom_timeout
        
    ctypedef enum pj_ice_sess_role:
        PJ_ICE_SESS_ROLE_UNKNOWN,     
        PJ_ICE_SESS_ROLE_CONTROLLED,     
        PJ_ICE_SESS_ROLE_CONTROLLING     

    DEF _PJ_ICE_MAX_STUN = 2
    DEF _PJ_ICE_MAX_TURN = 3
    DEF _PJ_ICE_MAX_COMP = 4
    
    ctypedef struct pj_ice_strans_stun_cfg:
        int              af
        pj_stun_sock_cfg cfg
        unsigned         max_host_cands 
        pj_bool_t        loop_addr 
        pj_str_t         server 
        pj_uint16_t      port 
        pj_bool_t        ignore_stun_error

    ctypedef struct pj_ice_strans_turn_cfg:
        int                 af 
        pj_turn_sock_cfg    cfg 
        pj_str_t            server 
        pj_uint16_t         port 
        pj_turn_tp_type     conn_type 
        pj_stun_auth_cred   auth_cred 
        pj_turn_alloc_param alloc_param
        
    ctypedef struct pj_ice_strans_cfg_comp:
        pj_qos_type   qos_type
        pj_qos_params qos_params
        unsigned      so_rcvbuf_size
        unsigned      so_sndbuf_size
 
    ctypedef struct pj_ice_strans_cfg:
        int                    af
        pj_stun_config         stun_cfg 
        pj_dns_resolver*       resolver
        pj_ice_sess_options    opt 
        pj_ice_strans_stun_cfg stun 
        unsigned               stun_tp_cnt
        pj_ice_strans_stun_cfg stun_tp[_PJ_ICE_MAX_STUN]
        pj_ice_strans_turn_cfg turn
        unsigned               turn_tp_cnt 
        pj_ice_strans_turn_cfg turn_tp[_PJ_ICE_MAX_TURN]
        pj_ice_strans_cfg_comp comp[_PJ_ICE_MAX_COMP]

    ctypedef enum pj_ice_strans_op:
        PJ_ICE_STRANS_OP_INIT,     
        PJ_ICE_STRANS_OP_NEGOTIATION,     
        PJ_ICE_STRANS_OP_KEEP_ALIVE,     
        PJ_ICE_STRANS_OP_ADDR_CHANGE     

    ctypedef enum pj_ice_strans_state:
        PJ_ICE_STRANS_STATE_NULL,     
        PJ_ICE_STRANS_STATE_INIT,     
        PJ_ICE_STRANS_STATE_READY,     
        PJ_ICE_STRANS_STATE_SESS_READY,     
        PJ_ICE_STRANS_STATE_NEGO,     
        PJ_ICE_STRANS_STATE_RUNNING,     
        PJ_ICE_STRANS_STATE_FAILED     

    ctypedef struct pj_ice_strans:
        pass
        
    ctypedef struct pj_ice_strans_cb:
        void (*on_rx_data)(pj_ice_strans* ice_st, unsigned comp_id, void* pkt, pj_size_t size, const pj_sockaddr_t* src_addr, unsigned src_addr_len) 
        void (*on_ice_complete)(pj_ice_strans* ice_st, pj_ice_strans_op op, pj_status_t status)
 

    #STRANS
    cdef void           pj_ice_strans_cfg_default(pj_ice_strans_cfg* cfg) nogil
    cdef pj_status_t    pj_ice_strans_create(const char* name, const pj_ice_strans_cfg* cfg, unsigned comp_cnt, void* user_data, const pj_ice_strans_cb* cb, pj_ice_strans** p_ice_st) nogil
    cdef pj_status_t    pj_ice_strans_destroy(pj_ice_strans* ice_st) nogil
    cdef pj_status_t    pj_ice_strans_enum_cands(pj_ice_strans* ice_st, unsigned comp_id, unsigned* count, pj_ice_sess_cand cand[]) nogil
    cdef pj_status_t    pj_ice_strans_get_def_cand(pj_ice_strans* ice_st, unsigned comp_id, pj_ice_sess_cand *cand) nogil
    cdef pj_grp_lock_t* pj_ice_strans_get_grp_lock (pj_ice_strans* ice_st) nogil
    cdef pj_status_t    pj_ice_strans_get_ufrag_pwd(pj_ice_strans* ice_st, pj_str_t* loc_ufrag, pj_str_t* loc_pwd, pj_str_t* rem_ufrag, pj_str_t* rem_pwd) nogil     
    cdef void*          pj_ice_strans_get_user_data(pj_ice_strans* ice_st) nogil
    cdef pj_status_t    pj_ice_strans_init_ice(pj_ice_strans* ice_st, pj_ice_sess_role role, const pj_str_t* local_ufrag, const pj_str_t* local_passwd) nogil    
    cdef pj_status_t    pj_ice_strans_sendto(pj_ice_strans* ice_st, unsigned comp_id, const void* data, pj_size_t data_len, const pj_sockaddr_t* dst_addr, int dst_addr_len) nogil
    cdef pj_status_t    pj_ice_strans_start_ice(pj_ice_strans* ice_st, const pj_str_t* rem_ufrag, const pj_str_t* rem_passwd, unsigned rcand_cnt, const pj_ice_sess_cand rcand[]) nogil
    cdef void           pj_ice_strans_stun_cfg_default(pj_ice_strans_stun_cfg* cfg) nogil
    cdef void           pj_ice_strans_turn_cfg_default(pj_ice_strans_turn_cfg* cfg) nogil
 
