from migen import *
from migen.genlib import fifo

from litex.soc.interconnect.csr import *
from litex.soc.interconnect.csr_eventmanager import *
from litex.soc.interconnect import wishbone

from cores.utils.wishbone import *

class _SPIMaster(Module):
    #
    # ported to migen from: https://github.com/olofk/simple_spi
    #
    def __init__(self, pads, size):
        self.divclk = Signal(16)
        self.cpol   = Signal()
        self.cpha   = Signal()

        self.state  = Signal(2)
        self.cntclk = Signal(16)
        self.tick   = Signal()
        self.byte   = Signal(8)
        self.count  = Signal(3)

        self.submodules.fifo_tx = fifo.SyncFIFO(8, size)
        self.submodules.fifo_rx = fifo.SyncFIFO(8, size)

        self.comb += [
            pads.mosi.eq(self.byte[7]),
            self.tick.eq(self.cntclk == 0),
            self.fifo_rx.din.eq(self.byte)
        ]

        self.sync += [
            # ticker
            If(self.cntclk == 0,
                self.cntclk.eq(self.divclk)
            ).Else(
                self.cntclk.eq(self.cntclk-1)
            ),

            # reset fifo latches
            self.fifo_tx.re.eq(0),
            self.fifo_rx.we.eq(0),

            Case(self.state, {
                0: [
                    self.cntclk.eq(self.divclk),
                    self.count.eq(7),
                    pads.sclk.eq(self.cpol),
                    If(self.fifo_tx.readable,
                        self.byte.eq(self.fifo_tx.dout),
                        self.fifo_tx.re.eq(1),
                        If(self.cpha, pads.sclk.eq(~pads.sclk)),
                        self.state.eq(2),
                    )
                ],
                2: [
                    If(self.tick,
                        pads.sclk.eq(~pads.sclk),
                        self.state.eq(1),
                    )
                ],
                1: [
                    self.byte.eq(Cat(pads.miso, self.byte[0:7])),
                    self.count.eq(self.count - 1),
                    If(self.count == 0,
                        self.fifo_rx.we.eq(1),
                        pads.sclk.eq(self.cpol),
                        self.state.eq(0)
                    ).Else(
                        pads.sclk.eq(~pads.sclk),
                        self.state.eq(2),
                    )
                ]
            })
        ]


class SPIMaster(Module, AutoCSR):
    def __init__(self, pads=None, cs_width=1, size=1024, fifo_size=16, busmaster=False):
        if pads is None:
            pads = Record([("sclk", 1), ("cs_n", cs_width), ("mosi", 1), ("miso", 1)])
        self.size   = size
        self.pads   = pads
        self.start  = Signal()
        self.done   = Signal()
        self.len    = Signal(32)

        txbus = wishbone.Interface()
        rxbus = wishbone.Interface()
        self.submodules.txs = WishboneByteStreamTX(txbus)
        self.submodules.rxs = WishboneByteStreamRX(rxbus)
        self.submodules.spi = _SPIMaster(self.pads, fifo_size)

        self.comb += [
            self.txs.len.eq(self.len),
            self.rxs.len.eq(self.len),
            self.txs.start.eq(self.start),
            self.rxs.start.eq(self.start),
            self.done.eq(self.rxs.done),
            # send
            self.spi.fifo_tx.din.eq(self.txs.source.data),
            self.spi.fifo_tx.we.eq(self.txs.source.valid),
            self.txs.source.ready.eq(self.spi.fifo_tx.writable),
            # receive
            self.rxs.sink.data.eq(self.spi.fifo_rx.dout),
            self.rxs.sink.valid.eq(self.spi.fifo_rx.readable),
            self.spi.fifo_rx.re.eq(self.rxs.sink.ready)
        ]

        self.mem_size = CSRConstant(size)
        self.cs_width = CSRConstant(cs_width)

        # irq interface
        self.submodules.ev = EventManager()
        self.ev.done = EventSourcePulse()
        self.ev.finalize()

        # csr interface
        self._mode    = CSRStorage(3)
        self._divclk  = CSRStorage(16)
        self._length  = CSRStorage(16)
        self._control = CSRStorage(3)
        self._cs      = CSRStorage(cs_width)
        self._status  = CSRStorage(1)

        self.comb += [
            self.ev.done.trigger.eq(self.done),
            self.spi.cpol.eq(self._mode.storage[0]),
            self.spi.cpha.eq(self._mode.storage[1]),
            If(self._mode.storage[2],
                self.pads.cs_n.eq(self._cs.storage)
            ).Else(
                self.pads.cs_n.eq(~self._cs.storage)
            ),
            self.spi.divclk.eq(self._divclk.storage),
            self.len.eq(Cat(self._length.storage, Replicate(0, 16))),
            self.start.eq(self._control.storage[0]),
            self.txs.ignore.eq(self._control.storage[1]),
            self.rxs.ignore.eq(self._control.storage[2])
        ]

        # take care of start / running flags
        self.sync += [
            If(self.start,
                self._status.storage[0].eq(1),
                self._control.storage[0].eq(0)
            ),
            If (self.done,
                self._status.storage[0].eq(0)
            ),
        ]

        # wishbone interface
        if busmaster:
            self.submodules.mem_port1 = wishbone.SRAM(size)
            self.slave_bus  = self.mem_port1.bus
            self.master_bus = wishbone.Interface()
            self.submodules.arbiter = wishbone.Arbiter([txbus, rxbus], self.master_bus)
            self._can_dma = CSRConstant(1)
            self._txadr = CSRStorage(32)
            self._rxadr = CSRStorage(32)
            self.comb += [
                self.txs.adr.eq(self._txadr.storage[2:]),
                self.rxs.adr.eq(self._rxadr.storage[2:])
            ]
        else:
            self.submodules.mem_port1 = wishbone.SRAM(size)
            self.submodules.arbiter = wishbone.Arbiter([txbus, rxbus], self.mem_port1.bus)
            self.submodules.mem_port2 = wishbone.SRAM(self.mem_port1.mem)
            self.slave_bus = self.mem_port2.bus
            self.comb += [
                self.txs.adr.eq(0),
                self.rxs.adr.eq(0)
            ]


    def get_size(self):
        return max(self.size, 0x1000)


#
# unit tests
#

def _testbenchrw(dut, silent=True):
    # fill tx memory with test pattern
    for i in range(0, dut.size, 4):
        val = i | ((i+1) << 8) | ((i+2) << 16) | ((i+3) << 24)
        yield from dut.slave_bus.write(i//4, val)
    # setup transfer
    yield from dut._mode.write(0)
    yield from dut._divclk.write(1)
    yield from dut._length.write(17)
    # start transfer
    yield from dut._control.write(1)
    # wait ready
    while not (yield dut.done):
        if not silent:
            print("spi.state", (yield dut.spi.state),
                  "txs.valid=", (yield dut.txs.source.valid),
                  "rxs.ready=", (yield dut.rxs.sink.valid),
                  "spi.count=", (yield dut.spi.count),
                  "pads.mosi=", (yield dut.pads.mosi),
                  "pads.miso=", (yield dut.pads.miso)
            )
        yield
    yield
    # print results
    print("txs=", (yield dut.txs.fsm.state), "rxs=", (yield dut.rxs.fsm.state), "done=", (yield dut.done))

    # clear tx memory to be sure of results
    #for i in range(0, dut.size, 4):
    #    yield from dut.bus.write(i//4, 0)

    # print read memory
    for i in range(0, 32, 4):
        print(hex((yield from dut.slave_bus.read((dut.size+i)//4))))


def _testbench(dut):
    silent = True
    print("running testbench...")
    print("1. run")
    yield from _testbenchrw(dut, silent)
    print("2. run")
    yield from _testbenchrw(dut, silent)
    print("done.")


class _Dut(SPIMaster):
    def __init__(self, busmaster=True):
        SPIMaster.__init__(self, busmaster=busmaster)
        if busmaster:
            self.submodules.mem_port2 = wishbone.SRAM(self.mem_port1.mem)
            self.submodules.arbiter = wishbone.Arbiter([self.master_bus], self.mem_port2.bus)
        self.sync += self.pads.miso.eq(~self.pads.mosi)


if __name__ == "__main__":
    dut = _Dut()
    run_simulation(dut, _testbench(dut), vcd_name="/tmp/test.vcd")
