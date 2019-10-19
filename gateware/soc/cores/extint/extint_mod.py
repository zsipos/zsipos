
from migen import *


class IRQ():
    def __init__(self):
        self.irq = Signal(1)


class EXTINT(Module):

    def __init__(self, platform, name, number=None):
        self.ev = IRQ()
        pin = platform.request(name, number)
        self.comb += self.ev.irq.eq(pin)

