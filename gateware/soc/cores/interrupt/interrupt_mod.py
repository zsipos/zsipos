
from migen import *


class _IRQ():
    def __init__(self):
        self.irq = Signal(1)

class Interrupt(Module):
    def __init__(self):
        self.ev = _IRQ()

class ExtInterrupt(Interrupt):
    def __init__(self, platform, name, number=None):
        Interrupt.__init__(self)
        pin = platform.request(name, number)
        self.comb += self.ev.irq.eq(pin)

