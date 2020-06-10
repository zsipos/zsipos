#include <stdio.h>
#include <camkes.h>
#include <picotcp.h>
#include <remcalls.h>

typedef struct sock_priv {
	void (*wakeup)(uint16_t ev, void *s, void *priv);
	void *priv;
} sock_priv_t;

static void do_master_request()
{
	int error;

	*((char*)m_request_reg) = 1;
	error = m_confirm_sem_wait();
}

static void handle_socket_event(uint16_t evt, struct pico_socket *s)
{
	remcb_arg_t                   *arg = (void*)m_buffer;
	remcb_pico_socket_event_arg_t *a = &arg->u.remcb_pico_socket_event_arg;
	sock_priv_t                   *priv = (sock_priv_t*)s->priv;

	arg->hdr.func = f_remcb_pico_socket_event;
	a->wakeup = priv->wakeup;
	a->evt    = evt;
	a->s      = s;
	a->priv   = priv->priv;
	do_master_request();
}

static void handle_rem_stack_lock(rem_arg_t *arg)
{
	int error = pico_stack_lock();
}

static void handle_rem_stack_unlock(rem_arg_t *arg)
{
	int error = pico_stack_unlock();
}

static void handle_rem_get_proto(rem_arg_t *arg)
{
	rem_res_t           *res = (rem_res_t*)arg;
	rem_get_proto_arg_t *a = &arg->u.rem_get_proto_arg;
	rem_get_proto_res_t *r = &res->u.rem_get_proto_res;
	struct pico_socket  *s;

	s = (struct pico_socket *)a->s;
	r->retval = s->proto->proto_number;
}

static void handle_rem_set_priv(rem_arg_t *arg)
{
	rem_res_t          *res = (rem_res_t*)arg;
	rem_set_priv_arg_t *a = &arg->u.rem_set_priv_arg;
	struct pico_socket *s;

	s = (struct pico_socket *)a->s;
	((sock_priv_t*)s->priv)->priv = a->priv;
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
	free(s->priv);
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
	struct pico_socket         *retval;
	sock_priv_t                *priv;

	priv = malloc(sizeof(sock_priv_t));
	if (!priv) {
		r->retval = NULL;
		res->hdr.pico_err = PICO_ERR_ENOMEM;
		return;
	}
	priv->wakeup = a->wakeup;

	retval = pico_socket_open(a->net, a->proto, handle_socket_event);
	if (retval) {
		retval->priv = priv;
		r->retval = (rem_pico_socket_t*)retval;
	} else {
		free(priv);
	}
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
	case f_rem_get_proto:
		handle_rem_get_proto(arg);
		break;
	case f_rem_set_priv:
		handle_rem_set_priv(arg);
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
