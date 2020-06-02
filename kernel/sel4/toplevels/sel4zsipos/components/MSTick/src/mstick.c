#include <stdio.h>
#include <camkes.h>

#include <litex.h>

static int msticks = 0;

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
	// clear hardware irq
	litex_csr_writeb(1, (volatile void *)reg + LITEX_TIMER1_EV_ENABLE_REG);
	// enable hardware irq
	litex_csr_writel(0, (volatile void *)reg + LITEX_TIMER1_LOAD_REG);
	litex_csr_writel(75000, (volatile void *)reg + LITEX_TIMER1_RELOAD_REG);
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

	msticks++;

	if (!(msticks % 1000))
		printf("one second mstick (%d)\n", msticks);

	tick0_emit();
	tick1_emit();

	// clear hardware irq
	litex_csr_writeb(1, (volatile void *)reg + LITEX_TIMER1_EV_PENDING_REG);

	// sel4 acknowledge irq
	error = irq_acknowledge();
}

