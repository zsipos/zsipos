// SPDX-FileCopyrightText: 2020 Stefan Adams <stefan.adams@vipcomag.de>
// SPDX-License-Identifier: GPL-3.0-or-later

#include <stdio.h>
#include <camkes.h>

#include <pico_stack.h>
#include <pico_ipv4.h>
#include <pico_icmp4.h>
#include <pico_dev_loop.h>

#include "sel4zsipos_config.h"

#include "pico_dev_litex.h"

int mstick = 0;

#if 0
int clk_get_time(void) {
	return mstick * TICKMUL;
}
#else
int clk_get_time(void)
{
	unsigned long retval;

	asm volatile ("csrr %0, 0xc01" : "=r"(retval)); // read CSR_TIME
	return retval/750;
}
#endif

int run(void)
{
    int error, id;
    struct pico_ip4 ipaddr, netmask;
    struct pico_device *devl;

    pico_stack_init();

    if (loopback) {
		devl = pico_loop_create();
		if (!devl) {
			dbg("can't create loop device!\n");
			return -1;
		}

		pico_string_to_ipv4("127.0.0.1", &ipaddr.addr);
		pico_string_to_ipv4("255.0.0.0", &netmask.addr);
		pico_ipv4_link_add(devl, ipaddr, netmask);
    }

    for (;;)
    {
    	int i;

    	tick_wait();
    	mstick++;
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
