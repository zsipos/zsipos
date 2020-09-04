// SPDX-FileCopyrightText: 2020 Stefan Adams <stefan.adams@vipcomag.de>
// SPDX-License-Identifier: GPL-3.0-or-later

#include <stdio.h>
#include <camkes.h>
#include <picotcp.h>
#include <pico_tcp.h>
#include <pico_dhcp_client.h>

typedef void *iprcchan_t;
#include <sel4ip.h>
#include <remcalls.h>

#include "pico_dev_litex.h"

#ifdef MINLOCK
#define SLOCK()		do_pico_stack_lock()
#define SUNLOCK()	do_pico_stack_unlock()
#else
#define SLOCK()
#define SUNLOCK()
#endif

static void *begin_master_request()
{
	int error = master_request_lock();
	return (void*)m_buffer;
}

static void do_master_request()
{
	int error;

	*((char*)m_request_reg) = 1;
	error = request_confirmed_wait();
}

static void end_master_request()
{
	int error = master_request_unlock();
}

static void handle_socket_event(uint16_t ev, struct pico_socket *s)
{
	remcb_arg_t                   *arg = begin_master_request();
	remcb_pico_socket_event_arg_t *a = &arg->u.remcb_pico_socket_event_arg;
	void                          *priv = s->priv;

	if (priv) {
		arg->hdr.func = f_remcb_pico_socket_event;
		a->ev         = ev;
		a->s          = s;
		a->priv       = priv;
		a->err        = pico_err;

		do_master_request();
	} else {
		if (ev & (PICO_SOCK_EV_CLOSE | PICO_SOCK_EV_FIN)) {
			pico_socket_close(s);
		}
	}
	end_master_request();
}

static inline void do_pico_stack_lock(void)
{
	int error = pico_stack_lock();
}

static inline void do_pico_stack_unlock(void)
{
	int error = pico_stack_unlock();
}

static void handle_rem_stack_lock(rem_arg_t *arg)
{
	do_pico_stack_lock();
}

static void handle_rem_stack_unlock(rem_arg_t *arg)
{
	do_pico_stack_unlock();
}

static void handle_rem_set_priv(rem_arg_t *arg)
{
	rem_res_t          *res = (rem_res_t*)arg;
	rem_set_priv_arg_t *a = &arg->u.rem_set_priv_arg;
	struct pico_socket *s;

	s = (struct pico_socket *)a->s;
	s->priv = a->priv;
}

static void handle_rem_init_eth(rem_arg_t *arg)
{
	rem_res_t          *res = (rem_res_t*)arg;
	rem_init_eth_arg_t *a = &arg->u.rem_init_eth_arg;
	rem_init_eth_res_t *r = &res->u.rem_init_eth_res;

	do_pico_stack_lock();

    r->retval = pico_litex_create(a->macaddr) ? 0 : -1;

	do_pico_stack_unlock();
}

static void handle_rem_get_devices(rem_arg_t *arg)
{
	rem_res_t             *res = (rem_res_t*)arg;
	rem_get_devices_res_t *r = &res->u.rem_get_devices_res;
	struct pico_tree_node *n;

	do_pico_stack_lock();

	r->devices.count = 0;
	pico_tree_foreach(n, &Device_tree)
	{
		struct pico_device *dev = n->keyValue;

		if (r->devices.count == MAX_DEVICES) {
			printf("warning: get_devices: more than MAX_DEVICES.\n");
			break;
		}
		if (strcmp(dev->name, "loop") == 0)
			strncpy(r->devices.names[r->devices.count], "lo", MAX_DEVICE_NAME);
		else
			strncpy(r->devices.names[r->devices.count], dev->name, MAX_DEVICE_NAME);
		r->devices.count++;
	}
	r->retval = 0;

	do_pico_stack_unlock();
}

static void handle_rem_get_device_config(rem_arg_t *arg)
{
	rem_res_t                   *res = (rem_res_t*)arg;
	rem_get_device_config_arg_t *a = &arg->u.rem_get_device_config_arg;
	rem_get_device_config_res_t *r = &res->u.rem_get_device_config_res;
	char                        *name;
	struct pico_device          *dev;
	struct pico_ipv4_link       *ip4l;

	do_pico_stack_lock();

	name = strcmp(a->name, "lo") == 0 ? "loop" : a->name;
	dev = pico_get_device(name);
	if (!dev) {
		r->retval = -1;
		goto quit;
	}
	memset(&r->config, 0, sizeof(r->config));
	name = strcmp(dev->name, "loop") == 0 ? "lo" : dev->name;
	strncpy(r->config.name, name, MAX_DEVICE_NAME);
	if (dev->eth) {
		r->config.hasmac = 1;
		r->config.mac = dev->eth->mac;
	}
	r->config.mtu = dev->mtu;
	ip4l = pico_ipv4_link_by_dev(dev);
	if (ip4l) {
		r->config.hasipv4link = 1;
		r->config.address.ip4 = ip4l->address;
		r->config.netmask.ip4 = ip4l->netmask;
	}
	r->retval = 0;

quit:

	do_pico_stack_unlock();
}

static void handle_rem_set_device_address(rem_arg_t *arg)
{
	rem_res_t                    *res = (rem_res_t*)arg;
	rem_set_device_address_arg_t *a = &arg->u.rem_set_device_address_arg;
	rem_set_device_address_res_t *r = &res->u.rem_set_device_address_res;
	struct pico_device           *dev;
	struct pico_ipv4_link        *ip4l;

	do_pico_stack_lock();

	if (strcmp(a->name, "lo") == 0) {
		r->retval = 0;
		goto quit;
	}

	dev = pico_get_device(a->name);
	if (!dev) {
		r->retval = -1;
		goto quit;
	}

	ip4l = pico_ipv4_link_by_dev(dev);
	if (ip4l)
		pico_ipv4_link_del(dev, ip4l->address);

	r->retval = pico_ipv4_link_add(dev, a->address.ip4, a->netmask.ip4);

quit:

	do_pico_stack_unlock();
}

static void handle_rem_device_down(rem_arg_t *arg)
{
	rem_res_t             *res = (rem_res_t*)arg;
	rem_device_down_arg_t *a = &arg->u.rem_device_down_arg;
	rem_device_down_res_t *r = &res->u.rem_device_down_res;
	struct pico_device    *dev;
	struct pico_ipv4_link *ip4l;

	do_pico_stack_lock();

	if (strcmp(a->name, "lo") == 0) {
		r->retval = -1;
		goto quit;
	}
	dev = pico_get_device(a->name);
	if (!dev) {
		r->retval = -1;
		goto quit;
	}
	ip4l = pico_ipv4_link_by_dev(dev);
	if (ip4l)
		pico_ipv4_link_del(dev, ip4l->address);
	r->retval = 0;

quit:

	do_pico_stack_unlock();
}

static void handle_rem_device_addroute(rem_arg_t *arg)
{
	rem_res_t                 *res = (rem_res_t*)arg;
	rem_device_addroute_arg_t *a = &arg->u.rem_device_addroute_arg;
	rem_device_addroute_res_t *r = &res->u.rem_device_addroute_res;
	struct pico_device        *dev;
	struct pico_ipv4_link     *ip4l;
	char                      *devname = a->name;

	do_pico_stack_lock();

	if (strcmp(devname, "lo") == 0) {
		r->retval = -1;
		goto quit;
	}
	if (!devname[0])
		devname = "eth0";
	dev = pico_get_device(devname);
	if (!dev) {
		printf("device %s not found\n", a->name);
		r->retval = -1;
		goto quit;
	}
	ip4l = pico_ipv4_link_by_dev(dev);
	if (!ip4l) {
		printf("device %s has no link!\n", a->name);
		r->retval = -1;
		goto quit;
	}
	if (pico_ipv4_route_add(a->address.ip4, a->genmask.ip4, a->gateway.ip4, a->metric, ip4l) < 0)
		r->retval = 0 - pico_err;
	else
		r->retval = 0;

quit:

	do_pico_stack_unlock();
}

extern struct pico_tree Routes;

static void handle_rem_get_routes(rem_arg_t *arg)
{
	rem_res_t              *res = (rem_res_t*)arg;
	rem_get_routes_res_t   *r = &res->u.rem_get_routes_res;
	struct pico_tree_node  *index;
	pico_route_t           *route;

	do_pico_stack_lock();

	r->routes.count = 0;
	pico_tree_foreach(index, &Routes)
	{
		struct pico_ipv4_route *r4 = index->keyValue;
		int                     flags = 1;

		if (r->routes.count == MAX_ROUTES) {
			printf("warning: get_routes: more than MAX_ROUTES.\n");
			break;
		}

		if (r4->netmask.addr == 0)
			flags += 2;
		route = &r->routes.routes[r->routes.count];
		if (strcmp(r4->link->dev->name, "loop") == 0)
			strcpy(route->devname, "lo");
		else
			strcpy(route->devname, r4->link->dev->name);
		route->dest.ip4    = r4->dest;
		route->gateway.ip4 = r4->gateway;
		route->netmask.ip4 = r4->netmask;
		route->flags       = flags;
		route->metric      = r4->metric;
		r->routes.count++;
	}
	r->retval = 0;

	do_pico_stack_unlock();
}

/* dhcp */

/* dhcp blocks the rem_call until a dhcp result is returned ... */

static uint32_t    dhcp_xid = -1;
static int         dhcp_finished;
static int         dhcp_code;
static pico_err_t  dhcp_err;

static void dhcp_callback(void *cli, int code)
{
	dhcp_err      = pico_err;
	dhcp_code     = code;
	dhcp_finished = 1;
}

static void handle_rem_dhcp(rem_arg_t *arg)
{
	rem_res_t          *res = (rem_res_t*)arg;
	rem_dhcp_arg_t     *a = &arg->u.rem_dhcp_arg;
	rem_dhcp_res_t     *r = &res->u.rem_dhcp_res;
	struct pico_device *dev;
	int                 ret;

	do_pico_stack_lock();

	if (dhcp_xid != -1) {
		pico_dhcp_client_abort(dhcp_xid);
		dhcp_xid = -1;
	}

	dhcp_finished = 0;

	dev = pico_get_device(a->name);
	if (!dev) {
		printf("dhcp: device %s not found\n", a->name);
		r->retval = -1;
		res->hdr.pico_err = pico_err;
		do_pico_stack_unlock();
		return;
	}

	ret = pico_dhcp_initiate_negotiation(dev, dhcp_callback, &dhcp_xid);

	r->retval = 0;
	res->hdr.pico_err = pico_err;

	do_pico_stack_unlock();

	if (ret) {
		r->retval = -1;
		printf("dhcp: can not start negotiation\n");
		return;
	}

	while (!dhcp_finished)
		seL4_Yield();

	if (dhcp_code == PICO_DHCP_SUCCESS) {
		void *cli = pico_dhcp_get_identifier(dhcp_xid);
		int   count = 0;

		for(;;) {
			struct pico_ip4 addr;

			addr = pico_dhcp_get_nameserver(cli, count);
			if (addr.addr <= 0)
				break;
			r->nameserver_addrs[count].ip4 = addr;
			r->nameserver_count = ++count;
		}
	} else {
		printf("dhcp: failed\n");
		r->retval = -1;
		res->hdr.pico_err = dhcp_err;
	}
}

/* ping */

/* ping blocks the rem_call until all replies are returned... */

static int                 ping_replies;
static sel4ip_ping_stat_t *ping_stats;

static void ping4_callback(struct pico_icmp4_stats *stats)
{
	sel4ip_ping_stat_t *p = &ping_stats[ping_replies];

	p->err  = stats->err;
	p->size = stats->size;
	p->seq  = stats->seq;
	p->ttl  = stats->ttl;
	p->time = stats->time;

	ping_replies++;
}

static void handle_rem_ping(rem_arg_t *arg)
{
	rem_res_t      *res = (rem_res_t*)arg;
	rem_ping_arg_t *a = &arg->u.rem_ping_arg;
	rem_ping_res_t *r = &res->u.rem_ping_res;
	int             count, ret, i;

	do_pico_stack_lock();

	count = a->count;
	ping_replies = 0;
	ping_stats = r->stats;

	for (i = 0; i < count; i++)
		r->stats[i].err = 0xffff;

	{	char host[16];

		pico_ipv4_to_string(host, a->addr.ip4.addr);
		ret = pico_icmp4_ping(host, count, 1000, 10000, 64, ping4_callback);

		r->retval = 0;
		res->hdr.pico_err = pico_err;

		do_pico_stack_unlock();

		if (ret == -1) {
			r->retval = -1;
			return;
		}
	}

	while (ping_replies < count)
		seL4_Yield();
}

/**/

static void handle_rem_pico_socket_shutdown(rem_arg_t *arg)
{
	rem_res_t                      *res = (rem_res_t*)arg;
	rem_pico_socket_shutdown_arg_t *a = &arg->u.rem_pico_socket_shutdown_arg;
	rem_pico_socket_shutdown_res_t *r = &res->u.rem_pico_socket_shutdown_res;
	struct pico_socket             *s;

	do_pico_stack_lock();

	s = (struct pico_socket *)a->s;
	r->retval = pico_socket_shutdown(s, a->mode);
	res->hdr.pico_err = pico_err;

	do_pico_stack_unlock();
}

static void handle_rem_pico_socket_connect(rem_arg_t *arg)
{
	rem_res_t                     *res = (rem_res_t*)arg;
	rem_pico_socket_connect_arg_t *a = &arg->u.rem_pico_socket_connect_arg;
	rem_pico_socket_connect_res_t *r = &res->u.rem_pico_socket_connect_res;
	struct pico_socket            *s;

	SLOCK();

	s = (struct pico_socket *)a->s;
	r->retval = pico_socket_connect(s, &a->srv_addr, a->remote_port);
	res->hdr.pico_err = pico_err;

	SUNLOCK();
}

static void handle_rem_pico_socket_close(rem_arg_t *arg)
{
	rem_res_t                   *res = (rem_res_t*)arg;
	rem_pico_socket_close_arg_t *a = &arg->u.rem_pico_socket_close_arg;
	rem_pico_socket_close_res_t *r = &res->u.rem_pico_socket_close_res;
	struct pico_socket          *s;

	s = (struct pico_socket *)a->s;
	r->retval = pico_socket_close(s);
	res->hdr.pico_err = pico_err;
}

static void handle_rem_pico_socket_bind(rem_arg_t *arg)
{
	rem_res_t                  *res = (rem_res_t*)arg;
	rem_pico_socket_bind_arg_t *a = &arg->u.rem_pico_socket_bind_arg;
	rem_pico_socket_bind_res_t *r = &res->u.rem_pico_socket_bind_res;
	struct pico_socket         *s;
	uint16_t                    port;

	SLOCK();

	s = (struct pico_socket *)a->s;
	port = a->port;
	r->retval = pico_socket_bind(s, &a->local_addr, &port);
	r->port   = port;
	res->hdr.pico_err = pico_err;

	SUNLOCK();
}

static void handle_rem_pico_socket_getname(rem_arg_t *arg)
{
	rem_res_t                     *res = (rem_res_t*)arg;
	rem_pico_socket_getname_arg_t *a = &arg->u.rem_pico_socket_getname_arg;
	rem_pico_socket_getname_res_t *r = &res->u.rem_pico_socket_getname_res;
	struct pico_socket            *s;

	SLOCK();

	s = (struct pico_socket *)a->s;
	if (a->peer)
		r->retval = pico_socket_getpeername(s, &r->local_addr, &r->port, &r->proto);
	else
		r->retval = pico_socket_getname(s, &r->local_addr, &r->port, &r->proto);
	res->hdr.pico_err = pico_err;

	SUNLOCK();
}

static void handle_rem_pico_socket_accept(rem_arg_t *arg)
{
	rem_res_t                    *res = (rem_res_t*)arg;
	rem_pico_socket_accept_arg_t *a = &arg->u.rem_pico_socket_accept_arg;
	rem_pico_socket_accept_res_t *r = &res->u.rem_pico_socket_accept_res;
	struct pico_socket           *s;

	s = (struct pico_socket *)a->s;
	r->retval = (rem_pico_socket_t*)pico_socket_accept(s, &r->orig, &r->port);
	res->hdr.pico_err = pico_err;
}

static void handle_rem_pico_socket_listen(rem_arg_t *arg)
{
	rem_res_t                    *res = (rem_res_t*)arg;
	rem_pico_socket_listen_arg_t *a = &arg->u.rem_pico_socket_listen_arg;
	rem_pico_socket_listen_res_t *r = &res->u.rem_pico_socket_listen_res;
	struct pico_socket           *s;

	SLOCK();

	s = (struct pico_socket *)a->s;
	r->retval = pico_socket_listen(s, a->backlog);
	res->hdr.pico_err = pico_err;

	SUNLOCK();
}

static void handle_rem_pico_socket_sendto(rem_arg_t *arg)
{
	rem_res_t                    *res = (rem_res_t*)arg;
	rem_pico_socket_sendto_arg_t *a = &arg->u.rem_pico_socket_sendto_arg;
	rem_pico_socket_sendto_res_t *r = &res->u.rem_pico_socket_sendto_res;
	struct pico_socket           *s;

	SLOCK();

	s = (struct pico_socket *)a->s;
	r->retval = pico_socket_sendto(s, &a->buf[0], a->len, &a->dst, a->remote_port);
	res->hdr.pico_err = pico_err;

	SUNLOCK();
}

static void handle_rem_pico_socket_send(rem_arg_t *arg)
{
	rem_res_t                  *res = (rem_res_t*)arg;
	rem_pico_socket_send_arg_t *a = &arg->u.rem_pico_socket_send_arg;
	rem_pico_socket_send_res_t *r = &res->u.rem_pico_socket_send_res;
	struct pico_socket         *s;

	SLOCK();

	s = (struct pico_socket *)a->s;
	r->retval = pico_socket_send(s, &a->buf[0], a->len);
	res->hdr.pico_err = pico_err;

	SUNLOCK();
}

static void handle_rem_pico_socket_recvfrom(rem_arg_t *arg)
{
	rem_res_t                      *res = (rem_res_t*)arg;
	rem_pico_socket_recvfrom_arg_t *a = &arg->u.rem_pico_socket_recvfrom_arg;
	rem_pico_socket_recvfrom_res_t *r = &res->u.rem_pico_socket_recvfrom_res;
	struct pico_socket             *s;

	if (a->lock)
		SLOCK();

	s = (struct pico_socket *)a->s;
	r->retval = pico_socket_recvfrom(s, &r->buf[0], a->len, &r->orig, &r->local_port);
	if (s->proto->proto_number == PICO_PROTO_UDP)
		r->more = s->q_in.size > 0;
	else
		r->more = !pico_tcp_queue_in_is_empty(s);
	res->hdr.pico_err = pico_err;

	if (a->lock)
		SUNLOCK();
}

static void handle_rem_pico_socket_udp_poll(rem_arg_t *arg)
{
	rem_res_t                      *res = (rem_res_t*)arg;
	rem_pico_socket_udp_poll_arg_t *a = &arg->u.rem_pico_socket_udp_poll_arg;
	rem_pico_socket_udp_poll_res_t *r = &res->u.rem_pico_socket_udp_poll_res;
	struct pico_socket             *s;

	s = (struct pico_socket *)a->s;
	r->retval = s->q_in.size > 0;
	res->hdr.pico_err = pico_err;
}

static void handle_rem_pico_socket_tcp_poll(rem_arg_t *arg)
{
	rem_res_t                      *res = (rem_res_t*)arg;
	rem_pico_socket_tcp_poll_arg_t *a = &arg->u.rem_pico_socket_tcp_poll_arg;
	rem_pico_socket_tcp_poll_res_t *r = &res->u.rem_pico_socket_tcp_poll_res;
	struct pico_socket             *s;

	s = (struct pico_socket *)a->s;
	r->retval = !pico_tcp_queue_in_is_empty(s);
	res->hdr.pico_err = pico_err;
}

static void handle_rem_pico_socket_open(rem_arg_t *arg)
{
	rem_res_t                  *res = (rem_res_t*)arg;
	rem_pico_socket_open_arg_t *a = &arg->u.rem_pico_socket_open_arg;
	rem_pico_socket_open_res_t *r = &res->u.rem_pico_socket_open_res;

	r->retval = (rem_pico_socket_t*)pico_socket_open(a->net, a->proto, handle_socket_event);
	res->hdr.pico_err = pico_err;
}

static void handle_rem_pico_socket_getoption(rem_arg_t *arg)
{
	rem_res_t                       *res = (rem_res_t*)arg;
	rem_pico_socket_getoption_arg_t *a = &arg->u.rem_pico_socket_getoption_arg;
	rem_pico_socket_getoption_res_t *r = &res->u.rem_pico_socket_getoption_res;
	struct pico_socket              *s;
	int                              optlen;

	SLOCK();

	s = (struct pico_socket *)a->s;
	optlen = a->optlen;
	r->retval = pico_socket_getoption(s, a->option, &r->value[0]);
	r->optlen = optlen;
	res->hdr.pico_err = pico_err;

	SUNLOCK();
}

static void handle_rem_pico_socket_setoption(rem_arg_t *arg)
{
	rem_res_t                       *res = (rem_res_t*)arg;
	rem_pico_socket_setoption_arg_t *a = &arg->u.rem_pico_socket_setoption_arg;
	rem_pico_socket_setoption_res_t *r = &res->u.rem_pico_socket_setoption_res;
	struct pico_socket              *s;

	SLOCK();

	s = (struct pico_socket *)a->s;
	r->retval = pico_socket_setoption(s, a->option, &a->value[0]);
	res->hdr.pico_err = pico_err;

	SUNLOCK();
}

void handle_remcall(void *buffer)
{
	rem_arg_t *arg = buffer;

	switch(arg->hdr.func) {
	case f_rem_stack_lock:
		handle_rem_stack_lock(arg);
		break;
	case f_rem_stack_unlock:
		handle_rem_stack_unlock(arg);
		break;
	case f_rem_set_priv:
		handle_rem_set_priv(arg);
		break;
	case f_rem_init_eth:
		handle_rem_init_eth(arg);
		break;
	case f_rem_get_devices:
		handle_rem_get_devices(arg);
		break;
	case f_rem_get_device_config:
		handle_rem_get_device_config(arg);
		break;
	case f_rem_set_device_address:
		handle_rem_set_device_address(arg);
		break;
	case f_rem_device_down:
		handle_rem_device_down(arg);
		break;
	case f_rem_device_addroute:
		handle_rem_device_addroute(arg);
		break;
	case f_rem_get_routes:
		handle_rem_get_routes(arg);
		break;
	case f_rem_dhcp:
		handle_rem_dhcp(arg);
		break;
	case f_rem_ping:
		handle_rem_ping(arg);
		break;
	case f_rem_pico_socket_shutdown:
		handle_rem_pico_socket_shutdown(arg);
		break;
	case f_rem_pico_socket_connect:
		handle_rem_pico_socket_connect(arg);
		break;
	case f_rem_pico_socket_close:
		handle_rem_pico_socket_close(arg);
		break;
	case f_rem_pico_socket_bind:
		handle_rem_pico_socket_bind(arg);
		break;
	case f_rem_pico_socket_getname:
		handle_rem_pico_socket_getname(arg);
		break;
	case f_rem_pico_socket_accept:
		handle_rem_pico_socket_accept(arg);
		break;
	case f_rem_pico_socket_listen:
		handle_rem_pico_socket_listen(arg);
		break;
	case f_rem_pico_socket_sendto:
		handle_rem_pico_socket_sendto(arg);
		break;
	case f_rem_pico_socket_send:
		handle_rem_pico_socket_send(arg);
		break;
	case f_rem_pico_socket_recvfrom:
		handle_rem_pico_socket_recvfrom(arg);
		break;
	case f_rem_pico_socket_udp_poll:
		handle_rem_pico_socket_udp_poll(arg);
		break;
	case f_rem_pico_socket_tcp_poll:
		handle_rem_pico_socket_tcp_poll(arg);
		break;
	case f_rem_pico_socket_open:
		handle_rem_pico_socket_open(arg);
		break;
	case f_rem_pico_socket_getoption:
		handle_rem_pico_socket_getoption(arg);
		break;
	case f_rem_pico_socket_setoption:
		handle_rem_pico_socket_setoption(arg);
		break;
	default:
		printf("unknown remcall function %d requested\n", arg->hdr.func);
		break;
	}
}
