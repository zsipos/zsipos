
from migen import *


class IRQ():
    def __init__(self):
        self.irq = Signal(1)


class EXTINT(Module):

    def __init__(self, platform, name, number=None):

        if number:
            name += str(number)

        self.ev = IRQ()
        print("TODO: connect interrupt pin in", __file__)

