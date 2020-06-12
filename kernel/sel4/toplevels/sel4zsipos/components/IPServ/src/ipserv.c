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

extern void handle_remcall(void *buffer);

void s_request_irq_handle(void)
{
    int error;

    // clear irq flag
    *((char*)s_request_reg) = 0;

    handle_remcall((void*)s_buffer);

    // trigger reply irq
    *((char*)s_confirm_reg) = 1;

    // acknowledge irq
    error = s_request_irq_acknowledge();
}

void m_confirm_irq_handle(void)
{
    int error;

    // clear irq flag
    *((char*)m_confirm_reg) = 0;

    error = request_confirmed_post();

    // acknowledge irq
    error = m_confirm_irq_acknowledge();
}

void eth_irq_handle(void)
{
    int error;

    pico_litex_handle_irq();

    // acknowledge irq
    error = eth_irq_acknowledge();
}
