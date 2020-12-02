// SPDX-FileCopyrightText: 2019 Stefan Adams <stefan.adams@vipcomag.de>
// SPDX-License-Identifier: GPL-3.0-or-later

#include <stdio.h>
#include <camkes.h>

#include <litex.h>
#include <sel4zsipos_config.h>

static void litex_stop_timer(void)
{
	// disable hardware timer
	litex_csr_writeb(0, (volatile void *)reg + LITEX_TIMER1_EN_REG);
	// disable hardware irq
	litex_csr_writeb(0, (volatile void *)reg + LITEX_TIMER1_EV_ENABLE_REG);
	// clear hardware irq
	litex_csr_writeb(1, (volatile void *)reg + LITEX_TIMER1_EV_PENDING_REG);
}

static void litex_start_timer(void)
{
	litex_stop_timer();
	// enable hardware irq
	litex_csr_writeb(1, (volatile void *)reg + LITEX_TIMER1_EV_ENABLE_REG);
	// set hardware parameters
	litex_csr_writel(0, (volatile void *)reg + LITEX_TIMER1_LOAD_REG);
	litex_csr_writel(75000*TICKMUL/2, (volatile void *)reg + LITEX_TIMER1_RELOAD_REG);
	// enable hardware timer
	litex_csr_writeb(1, (volatile void *)reg + LITEX_TIMER1_EN_REG);
}

void post_init(void)
{
	litex_start_timer();
}

void irq_handle(void) 
{
	int error;

	static unsigned int count = 0;

	if (count++ & 1)
		tick1_emit();
	else
		tick2_emit();

	// clear hardware irq
	litex_csr_writeb(1, (volatile void *)reg + LITEX_TIMER1_EV_PENDING_REG);

	// sel4 acknowledge irq
	error = irq_acknowledge();
}

