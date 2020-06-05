#include <stdio.h>
#include <camkes.h>

#include <pico_stack.h>
#include <pico_ipv4.h>
#include <pico_icmp4.h>
#include <pico_dev_loop.h>

#include "pico_dev_litex.h"


/* implement clk_get_time() */
static int msticks = 0;

int clk_get_time(void) {
	return msticks;
}


#define NUM_PING 10

static int finished = 0;

/* gets called when the ping receives a reply, or encounters a problem */
void cb_ping(struct pico_icmp4_stats *s)
{
    char host[30];
    pico_ipv4_to_string(host, s->dst.addr);
    if (s->err == 0) {
        /* if all is well, print some pretty info */
        printf("%lu bytes from %s: icmp_req=%lu ttl=%lu time=%lu ms\n", s->size,
                host, s->seq, s->ttl, (long unsigned int)s->time);
        if (s->seq >= NUM_PING)
            finished = 1;
    } else {
        /* if something went wrong, print it and signal we want to stop */
        printf("PING %lu to %s: Error %d\n", s->seq, host, s->err);
        finished = 1;
    }
}

int run(void)
{
    int error, id;
    struct pico_ip4 ipaddr, netmask;
    struct pico_device *devl, *deve;

    /* initialise the stack. Super important if you don't want ugly stuff like
     * segfaults and such! */
    pico_stack_init();

    if (loopback) {
		/* create the loop device */
		devl = pico_loop_create();
		if (!devl) {
			dbg("can't create loop device!\n");
			return -1;
		}

		/* assign the IP address to the loop interface */
		pico_string_to_ipv4("127.0.0.1", &ipaddr.addr);
		pico_string_to_ipv4("255.0.0.0", &netmask.addr);
		pico_ipv4_link_add(devl, ipaddr, netmask);
    }

    deve = pico_litex_create();
	if (!deve) {
		dbg("can't create loop device!\n");
		return -1;
	}
	/* assign the IP address to the ethernet interface */
	pico_string_to_ipv4("192.168.0.55", &ipaddr.addr);
	pico_string_to_ipv4("255.255.255.0", &netmask.addr);
	pico_ipv4_link_add(deve, ipaddr, netmask);

    id = pico_icmp4_ping("192.168.0.45", NUM_PING, 1000, 10000, 64, cb_ping);


    /* keep running stack ticks to have picoTCP do its network magic. Note that
     * you can do other stuff here as well, or sleep a little. This will impact
     * your network performance, but everything should keep working (provided
     * you don't go overboard with the delays). */
    for (;;)
    {
    	tick_wait();
    	msticks++;
    	error = pico_stack_lock();
        pico_stack_tick();
        error = pico_stack_unlock();
    }

	return 0;
}

void ipc_irq_handle(void)
{
    int error;

    error = pico_stack_lock();

    printf("\nipc irq\n");
    printf("data=%s\n", (char*)ipc_reg2);

    strcpy((char*)ipc_reg2, "Hello Linux!");
    *((char*)ipc_reg1) = 1;

    error = pico_stack_unlock();

    // clear irq flag
    *((char*)ipc_reg0) = 0;
    // acknowledge irq
    error = ipc_irq_acknowledge();
}

void eth_irq_handle(void)
{
    int error;

    pico_litex_handle_irq();

    // acknowledge irq
    error = eth_irq_acknowledge();
}
