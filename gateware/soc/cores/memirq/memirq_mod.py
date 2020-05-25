from migen import *

from litex.soc.interconnect.csr import *
from litex.soc.interconnect.csr_eventmanager import *


class MemIrq(Module, AutoCSR):

    def __init__(self):

        self.doirq  = CSRStorage(1)

        self.submodules.ev = EventManager()
        self.ev.doirq  = EventSourcePulse()
        self.ev.finalize()

        self.comb += [
            self.ev.doirq.trigger.eq(self.doirq.storage[0]),
        ]
