PROG=sel4iptool

KERNDIR=$(ZTOP)/kernel/linux/net/sel4ip

all: $(PROG)

clean:
	rm -f $(PROG)

$(PROG): sel4iptool.c $(KERNDIR)/sel4ip.h
	$(ZTC_CC) $(ZTC_CFLAGS) -I$(KERNDIR) -o $@ $<
