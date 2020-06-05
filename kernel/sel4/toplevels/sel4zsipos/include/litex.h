/* SPDX-License-Identifier: GPL-2.0 */
#ifndef _LINUX_LITEX_H
#define _LINUX_LITEX_H

#include "csroffsets.h"

static unsigned int LITEX_READ_REG(volatile void *_addr)
{
	volatile unsigned int *addr = _addr;
	return *addr;
}

static void LITEX_WRITE_REG(unsigned int val, volatile void *_addr)
{
	volatile unsigned int *addr = _addr;
	*addr = val;
}

static inline void litex_csr_writeb(unsigned char val, volatile void *reg)
{
	LITEX_WRITE_REG(val, reg);
}

static inline void litex_csr_writew(unsigned short val, volatile void *reg)
{
	litex_csr_writeb(val >>  8, reg + LITEX_CSR_OFFSET(0));
	litex_csr_writeb(val >>  0, reg + LITEX_CSR_OFFSET(1));
}

static inline void litex_csr_writel(unsigned int val, volatile void *reg)
{
	litex_csr_writeb(val >> 24, reg + LITEX_CSR_OFFSET(0));
	litex_csr_writeb(val >> 16, reg + LITEX_CSR_OFFSET(1));
	litex_csr_writeb(val >>  8, reg + LITEX_CSR_OFFSET(2));
	litex_csr_writeb(val >>  0, reg + LITEX_CSR_OFFSET(3));
}

static inline unsigned char litex_csr_readb(volatile void *reg)
{
	return LITEX_READ_REG(reg);
}

static inline unsigned short litex_csr_readw(volatile void *reg)
{
	return 	((unsigned short)litex_csr_readb(reg + LITEX_CSR_OFFSET(0)) <<  8) |
			((unsigned short)litex_csr_readb(reg + LITEX_CSR_OFFSET(1)) <<  0);
}

static inline unsigned int litex_csr_readl(volatile void *reg)
{
	return  ((unsigned int)litex_csr_readb(reg + LITEX_CSR_OFFSET(0)) << 24) |
			((unsigned int)litex_csr_readb(reg + LITEX_CSR_OFFSET(1)) << 16) |
			((unsigned int)litex_csr_readb(reg + LITEX_CSR_OFFSET(2)) <<  8) |
			((unsigned int)litex_csr_readb(reg + LITEX_CSR_OFFSET(3)) <<  0);
}

#endif /* _LINUX_LITEX_H */
