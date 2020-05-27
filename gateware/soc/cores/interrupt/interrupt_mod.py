
from migen import *


class _IRQ():
    def __init__(self):
        self.irq = Signal(1)

class Interrupt(Module):
    def __init__(self):
        Module.__init__(self)
        self.ev = _IRQ()

class ExtInterrupt(Interrupt):
    def __init__(self, platform, name, number=None, type="high"):
        Interrupt.__init__(self)
        pin = platform.request(name, number)
        if type == "high":
            self.comb += self.ev.irq.eq(pin)
        elif type == "low":
            self.comb += self.ev.irq.eq(~pin)
        else:
            assert False, 'type must be in ["high", "low"]'

