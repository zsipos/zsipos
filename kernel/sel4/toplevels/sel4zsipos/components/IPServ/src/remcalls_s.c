#include <stdio.h>
#include <camkes.h>
#include <picotcp.h>
#include <remcalls.h>

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

		do_master_request();
	} else {
		if (ev & (PICO_SOCK_EV_CLOSE | PICO_SOCK_EV_FIN)) {
			pico_socket_close(s);
		}
	}
	end_master_request();
}

static void handle_rem_stack_lock(rem_arg_t *arg)
{
	int error = pico_stack_lock();
}

static void handle_rem_stack_unlock(rem_arg_t *arg)
{
	int error = pico_stack_unlock();
}

static void handle_rem_set_priv(rem_arg_t *arg)
{
	rem_res_t          *res = (rem_res_t*)arg;
	rem_set_priv_arg_t *a = &arg->u.rem_set_priv_arg;
	struct pico_socket *s;

	s = (struct pico_socket *)a->s;
	s->priv = a->priv;
}

static void handle_rem_get_devices(rem_arg_t *arg)
{
	rem_res_t             *res = (rem_res_t*)arg;
	rem_get_devices_res_t *r = &res->u.rem_get_devices_res;
	struct pico_tree_node *n;

	r->devices.count = 0;
	pico_tree_foreach(n, &Device_tree)
	{
		struct pico_device *dev = n->keyValue;

		if (r->devices.count == MAX_DEVICES)
			break;
		if (strcmp(dev->name, "loop") == 0)
			strncpy(r->devices.names[r->devices.count], "lo", MAX_DEVICE_NAME);
		else
			strncpy(r->devices.names[r->devices.count], dev->name, MAX_DEVICE_NAME);
		r->devices.count++;
	}
	r->retval = 0;
}

static void handle_rem_get_device_config(rem_arg_t *arg)
{
	rem_res_t                   *res = (rem_res_t*)arg;
	rem_get_device_config_arg_t *a = &arg->u.rem_get_device_config_arg;
	rem_get_device_config_res_t *r = &res->u.rem_get_device_config_res;
	char                        *name;
	struct pico_device          *dev;
	struct pico_ipv4_link       *ip4l;

	name = strcmp(a->name, "lo") == 0 ? "loop" : a->name;
	dev = pico_get_device(name);
	if (!dev) {
		printf("device %s not found\n", name);
		r->retval = -1;
		return;
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
}

static void handle_rem_pico_socket_shutdown(rem_arg_t *arg)
{
	rem_res_t                      *res = (rem_res_t*)arg;
	rem_pico_socket_shutdown_arg_t *a = &arg->u.rem_pico_socket_shutdown_arg;
	rem_pico_socket_shutdown_res_t *r = &res->u.rem_pico_socket_shutdown_res;
	struct pico_socket             *s;

	s = (struct pico_socket *)a->s;
	r->retval = pico_socket_shutdown(s, a->mode);
	res->hdr.pico_err = pico_err;
}

static void handle_rem_pico_socket_connect(rem_arg_t *arg)
{
	rem_res_t                     *res = (rem_res_t*)arg;
	rem_pico_socket_connect_arg_t *a = &arg->u.rem_pico_socket_connect_arg;
	rem_pico_socket_connect_res_t *r = &res->u.rem_pico_socket_connect_res;
	struct pico_socket            *s;

	s = (struct pico_socket *)a->s;
	r->retval = pico_socket_connect(s, &a->srv_addr, a->remote_port);
	res->hdr.pico_err = pico_err;
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

	s = (struct pico_socket *)a->s;
	port = a->port;
	r->retval = pico_socket_bind(s, &a->local_addr, &port);
	r->port   = port;
	res->hdr.pico_err = pico_err;
}

static void handle_rem_pico_socket_getname(rem_arg_t *arg)
{
	rem_res_t                     *res = (rem_res_t*)arg;
	rem_pico_socket_getname_arg_t *a = &arg->u.rem_pico_socket_getname_arg;
	rem_pico_socket_getname_res_t *r = &res->u.rem_pico_socket_getname_res;
	struct pico_socket            *s;

	s = (struct pico_socket *)a->s;
	if (a->peer)
		r->retval = pico_socket_getpeername(s, &r->local_addr, &r->port, &r->proto);
	else
		r->retval = pico_socket_getname(s, &r->local_addr, &r->port, &r->proto);
	res->hdr.pico_err = pico_err;
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

	s = (struct pico_socket *)a->s;
	r->retval = pico_socket_listen(s, a->backlog);
	res->hdr.pico_err = pico_err;
}

static void handle_rem_pico_socket_sendto(rem_arg_t *arg)
{
	rem_res_t                    *res = (rem_res_t*)arg;
	rem_pico_socket_sendto_arg_t *a = &arg->u.rem_pico_socket_sendto_arg;
	rem_pico_socket_sendto_res_t *r = &res->u.rem_pico_socket_sendto_res;
	struct pico_socket           *s;

	s = (struct pico_socket *)a->s;
	r->retval = pico_socket_sendto(s, &a->buf[0], a->len, &a->dst, a->remote_port);
	res->hdr.pico_err = pico_err;
}

static void handle_rem_pico_socket_send(rem_arg_t *arg)
{
	rem_res_t                  *res = (rem_res_t*)arg;
	rem_pico_socket_send_arg_t *a = &arg->u.rem_pico_socket_send_arg;
	rem_pico_socket_send_res_t *r = &res->u.rem_pico_socket_send_res;
	struct pico_socket         *s;

	s = (struct pico_socket *)a->s;
	r->retval = pico_socket_send(s, &a->buf[0], a->len);
	res->hdr.pico_err = pico_err;
}

static void handle_rem_pico_socket_recvfrom(rem_arg_t *arg)
{
	rem_res_t                      *res = (rem_res_t*)arg;
	rem_pico_socket_recvfrom_arg_t *a = &arg->u.rem_pico_socket_recvfrom_arg;
	rem_pico_socket_recvfrom_res_t *r = &res->u.rem_pico_socket_recvfrom_res;
	struct pico_socket             *s;

	s = (struct pico_socket *)a->s;
	r->retval = pico_socket_recvfrom(s, &r->buf[0], a->len, &r->orig, &r->local_port);
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

	s = (struct pico_socket *)a->s;
	optlen = a->optlen;
	r->retval = pico_socket_getoption(s, a->option, &r->value[0]);
	r->optlen = optlen;
	res->hdr.pico_err = pico_err;
}

static void handle_rem_pico_socket_setoption(rem_arg_t *arg)
{
	rem_res_t                       *res = (rem_res_t*)arg;
	rem_pico_socket_setoption_arg_t *a = &arg->u.rem_pico_socket_setoption_arg;
	rem_pico_socket_setoption_res_t *r = &res->u.rem_pico_socket_setoption_res;
	struct pico_socket              *s;

	s = (struct pico_socket *)a->s;
	r->retval = pico_socket_setoption(s, a->option, &a->value[0]);
	res->hdr.pico_err = pico_err;
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
	case f_rem_get_devices:
		handle_rem_get_devices(arg);
		break;
	case f_rem_get_device_config:
		handle_rem_get_device_config(arg);
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
