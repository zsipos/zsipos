// SPDX-FileCopyrightText: 2020 Stefan Adams <stefan.adams@vipcomag.de>
// SPDX-License-Identifier: GPL-3.0-or-later

#include <camkes.h>

#include <picotcp.h>

#include <litex.h>

#include "pico_dev_litex.h"

#define LITEX_COUNTER_RESET			1000
#define LITEX_COUNTER_READER_READY	10

static volatile void *macadr;
static volatile void *phyadr;
static volatile void *rxbadr;
static volatile void *txbadr;

static int tx_slot = 0;

static struct pico_device *litex;

#define WITH_RINGBUF

#ifdef WITH_RINGBUF

#define RINGBUFFERS 20

typedef struct {
	uint8_t  buf[LITEX_ETHMAC_SLOT_SIZE];
	int      len;
} BufEntry;

static int wrpos = 0;
static int rdpos = 0;

static BufEntry ringbuf[RINGBUFFERS];

static inline int inc_pos(int pos)
{
	pos++;
	if (pos == RINGBUFFERS)
		pos = 0;
	return pos;
}

#endif

static void pico_litex_recv()
{
	int           error;
	unsigned char rx_slot;
	uint32_t      len;

	rx_slot = litex_csr_readb(macadr + LITEX_ETHMAC_SRAM_WRITER_SLOT_REG);
	len = (uint32_t)litex_csr_readl(macadr + LITEX_ETHMAC_SRAM_WRITER_LENGTH_REG);

#ifdef WITH_RINGBUF
	error = ringbuf_lock();

	memcpy(ringbuf[wrpos].buf, (void*)rxbadr + rx_slot * LITEX_ETHMAC_SLOT_SIZE, len);
	ringbuf[wrpos].len = len;

	wrpos = inc_pos(wrpos);
	if (wrpos == rdpos) {
		printf("WARNING: pico_dev_litex: queue reading slow\n");
		rdpos = inc_pos(rdpos);
	}

	error = ringbuf_unlock();
#else
	error = pico_stack_lock();
    pico_stack_recv(litex, (void*)rxbadr + rx_slot * LITEX_ETHMAC_SLOT_SIZE, len);
	error = pico_stack_unlock();
#endif
}

#ifdef WITH_RINGBUF
static int pico_litex_poll(struct pico_device *dev, int loop_score)
{
	int error;

    if (loop_score <= 0)
        return 0;

    error = ringbuf_lock();

    if (rdpos != wrpos) {
    	loop_score--;
    	while(rdpos != wrpos) {
    		pico_stack_recv(dev, (void*)ringbuf[rdpos].buf, ringbuf[rdpos].len);
    		rdpos = inc_pos(rdpos);
    		// give interrupt a chance
    		error = ringbuf_unlock();
    		error = ringbuf_lock();
    	}
    }

    error = ringbuf_unlock();

    return loop_score;
}
#endif

static volatile int pendingout = 0;

void pico_litex_handle_irq()
{
	unsigned char reg;
	int           error;

	reg = litex_csr_readb(macadr + LITEX_ETHMAC_SRAM_READER_EV_PENDING_REG);
	if (reg) {
		// packet transmitted.
		litex_csr_writeb(1, macadr + LITEX_ETHMAC_SRAM_READER_EV_PENDING_REG);
		error = pendingout_lock();
		pendingout--;
		error = pendingout_unlock();
	}
	reg = litex_csr_readb(macadr + LITEX_ETHMAC_SRAM_WRITER_EV_PENDING_REG);
	if (reg) {
		pico_litex_recv();
		litex_csr_writeb(1, macadr + LITEX_ETHMAC_SRAM_WRITER_EV_PENDING_REG);
	}
}

static int pico_litex_send(struct pico_device *dev, void *buf, int len)
{
	int error;
	int r;

    IGNORE_PARAMETER(dev);

	if (len > LITEX_ETHMAC_SLOT_SIZE) {
		printf("WARNING: pico_dev_litex: packet too big. dropped.\n");
		return 0;
	}

	for(r = 0; (r < LITEX_COUNTER_READER_READY) && (pendingout == LITEX_ETHMAC_TX_SLOTS); r++)
		seL4_Yield();
	if (r == LITEX_COUNTER_READER_READY) {
		printf("pendingout wait limit\n", 0);
		printf("packet dropped.\n");
		return 0;
	}

	for(r = 0; (r < LITEX_COUNTER_READER_READY) && !(litex_csr_readb(macadr + LITEX_ETHMAC_SRAM_READER_READY_REG)); r++)
		seL4_Yield();
	if (r == LITEX_COUNTER_READER_READY) {
		printf("reader ready wait limit\n", 0);
		printf("packet dropped.\n");
		return 0;
	}

	memcpy((void*)txbadr + tx_slot * LITEX_ETHMAC_SLOT_SIZE, buf, len);
	litex_csr_writeb(tx_slot, macadr + LITEX_ETHMAC_SRAM_READER_SLOT_REG);
	litex_csr_writew(len, macadr + LITEX_ETHMAC_SRAM_READER_LENGTH_REG);

	error = pendingout_lock();
	pendingout++;
	error = pendingout_unlock();

	litex_csr_writeb(1, macadr + LITEX_ETHMAC_SRAM_READER_START_REG);

	tx_slot = (tx_slot + 1) % LITEX_ETHMAC_TX_SLOTS;

	return len;
}

static int check_hw_config()
{
	// check that buffers are page aligned
	if (LITEX_ETHMAC_RX_SLOTS != 2 || LITEX_ETHMAC1_RX_SLOTS != 2) {
		dbg("ERROR: litex eth rx slots must be 2\n");
		return 0;
	}
	if (LITEX_ETHMAC_TX_SLOTS != 2 || LITEX_ETHMAC1_TX_SLOTS != 2) {
		dbg("ERROR: litex eth tx slots must be 2\n");
		return 0;
	}
	if (LITEX_ETHMAC_SLOT_SIZE != 2048 || LITEX_ETHMAC1_SLOT_SIZE != 2048) {
		dbg("ERROR: litex eth slot_size must be 2048\n");
		return 0;
	}
	return 1;
}

static void reset_delay()
{
	int i;

	for (i = 0; i < LITEX_COUNTER_RESET; i++)
		seL4_Yield();
}

static int pico_litex_init()
{
	if (!check_hw_config())
		return 0;

	tx_slot = 0;

	// reset hardware
	litex_csr_writeb(0, phyadr + LITEX_ETHPHY_CRG_RESET_REG);
	reset_delay();
	litex_csr_writeb(1, phyadr + LITEX_ETHPHY_CRG_RESET_REG);
	reset_delay();
	litex_csr_writeb(0, phyadr + LITEX_ETHPHY_CRG_RESET_REG);

	// clear interrupts
	litex_csr_writeb(1, macadr + LITEX_ETHMAC_SRAM_READER_EV_PENDING_REG);
	litex_csr_writeb(1, macadr + LITEX_ETHMAC_SRAM_WRITER_EV_PENDING_REG);

	// enable interrupts
	litex_csr_writeb(1, macadr + LITEX_ETHMAC_SRAM_READER_EV_ENABLE_REG);
	litex_csr_writeb(1, macadr + LITEX_ETHMAC_SRAM_WRITER_EV_ENABLE_REG);

	return 1;
}

const char *ethname;

struct pico_device *pico_litex_create(unsigned char *mac)
{
    litex = PICO_ZALLOC(sizeof(struct pico_device));

    if (!litex) {
    	dbg("ERROR: can not allocate pico_device!");
        return NULL;
    }

    macadr = eth_reg0;
    phyadr = eth_reg1;
    rxbadr = eth_reg2;
    txbadr = eth_reg3;

    if (pico_device_init(stack, litex, ifname, mac) || !pico_litex_init()) {
        dbg("litex init failed.\n");
        pico_device_destroy(litex);
        return NULL;
    }
    ethname = ifname;

    litex->send = pico_litex_send;
#ifdef WITH_RINGBUF
    litex->poll = pico_litex_poll;
#endif

    return litex;
}

