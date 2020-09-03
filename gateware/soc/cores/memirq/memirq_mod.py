# SPDX-FileCopyrightText: 2020 Stefan Adams <stefan.adams@vipcomag.de>
# SPDX-License-Identifier: GPL-3.0-or-later

from migen import *

from litex.soc.interconnect.csr import *

from cores.interrupt.interrupt_mod import Interrupt


class MemIrq(Interrupt, AutoCSR):

    def __init__(self):
        Interrupt.__init__(self)

        self.doirq = CSRStorage(1)

        self.comb += [
            self.ev.irq.eq(self.doirq.storage[0])
        ]
