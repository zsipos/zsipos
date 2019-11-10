from migen import *

from litex.soc.interconnect import wishbone, stream
from litex.soc.interconnect.csr import *
from litex.soc.integration.common import mem_decoder

class WishboneByteStreamTX(Module):
    def __init__(self, bus):
        self.source = stream.Endpoint([("data", 8)])
        self.ignore = Signal()
        self.start  = Signal()
        self.done   = Signal()
        self.bus    = bus
        self.adr    = Signal(len(bus.adr))
        self.len    = Signal(32)
        self.rdadr  = Signal(len(bus.adr))
        self.rdlen  = Signal(32)
        self.word   = Signal(32)

        self.comb += [
            self.source.data.eq(self.word[:8]),
            self.bus.adr.eq(self.rdadr),
            self.bus.we.eq(0),
        ]

        self.submodules.fsm = fsm = FSM(reset_state="IDLE")
        fsm.act("IDLE",
            If(self.start,
                NextValue(self.rdadr, self.adr),
                NextValue(self.rdlen, 0),
                NextValue(self.bus.cyc, ~self.ignore),
                NextValue(self.bus.stb, ~self.ignore),
                NextState("READ-WORD")
            )
        )
        fsm.act("READ-WORD",
            If(self.ignore,
                NextValue(self.word, Replicate(0, 32)),
                NextState("SEND-BYTE")
            ).Else(
                If(self.bus.ack,
                    NextValue(self.bus.cyc, 0),
                    NextValue(self.bus.stb, 0),
                    NextValue(self.word, self.bus.dat_r),
                    NextState("SEND-BYTE")
                )
            )
        )
        fsm.act("SEND-BYTE",
            self.source.valid.eq(1),
            If(self.source.ready,
                If(self.rdlen == self.len-1,
                    self.done.eq(1),
                    NextState("IDLE")
                ).Else(
                    NextValue(self.rdlen, self.rdlen + 1),
                    NextState("NEXT-BYTE")
                )
            )
        )
        fsm.act("NEXT-BYTE",
            If((self.rdlen & 3) == 0,
                NextValue(self.rdadr, self.rdadr + 1),
                NextValue(self.bus.cyc, ~self.ignore),
                NextValue(self.bus.stb, ~self.ignore),
                NextState("READ-WORD")
            ).Else(
                NextValue(self.word, Cat(self.word[8:], Replicate(0, 8))),
                NextState("SEND-BYTE")
            )
        )


class WishboneByteStreamRX(Module):
    def __init__(self, bus):
        self.sink   = stream.Endpoint([("data", 8)])
        self.ignore = Signal()
        self.start  = Signal()
        self.done   = Signal()
        self.bus    = bus
        self.adr    = Signal(len(bus.adr))
        self.len    = Signal(32)
        self.wradr  = Signal(len(bus.adr))
        self.wrlen  = Signal(32)
        self.word   = Signal(32)

        self.comb += [
            self.bus.adr.eq(self.wradr),
            self.bus.we.eq(1),
            Case(self.wrlen & 3, {
                0: [
                    self.bus.dat_w.eq(self.word),
                    self.bus.sel.eq(0b1111)
                ],
                1: [
                    self.bus.dat_w.eq(Cat(self.word[24:], Replicate(24, 0))),
                    self.bus.sel.eq(0b0001)
                ],
                2: [
                    self.bus.dat_w.eq(Cat(self.word[16:], Replicate(16, 0))),
                    self.bus.sel.eq(0b0011)
                ],
                3: [
                    self.bus.dat_w.eq(Cat(self.word[8:], Replicate(8, 0))),
                    self.bus.sel.eq(0b0111)
                ]
            }),
        ]

        self.submodules.fsm = fsm = FSM(reset_state="IDLE")
        fsm.act("IDLE",
            If(self.start,
                NextValue(self.wradr, self.adr),
                NextValue(self.wrlen, 0),
                NextValue(self.word, 0),
                NextState("RECEIVE-BYTE")
            )
        )
        fsm.act("RECEIVE-BYTE",
            If(self.sink.valid,
                NextValue(self.word, Cat(self.word[8:], self.sink.data)),
                NextValue(self.wrlen, self.wrlen+1),
                NextState("CHECK-WRITE")
            )
        )
        fsm.act("CHECK-WRITE",
            If((self.wrlen == self.len) | ((self.wrlen & 3) == 0),
                NextValue(self.bus.cyc, ~self.ignore),
                NextValue(self.bus.stb, ~self.ignore),
                NextState("WRITE-WORD")
            ).Else(
                self.sink.ready.eq(1),
                NextState("RECEIVE-BYTE")
            )
        )
        fsm.act("WRITE-WORD",
            If(self.ignore,
                self.sink.ready.eq(1),
                If(self.wrlen == self.len,
                    self.done.eq(1),
                    NextState("IDLE")
                ).Else(
                    NextState("RECEIVE-BYTE")
                )
            ).Else(
                If(self.bus.ack,
                    self.sink.ready.eq(1),
                    NextValue(self.wradr, self.wradr + 1),
                    NextValue(self.bus.cyc, 0),
                    NextValue(self.bus.stb, 0),
                    If(self.wrlen == self.len,
                        self.done.eq(1),
                        NextState("IDLE")
                    ).Else(
                        NextValue(self.word, 0),
                        NextState("RECEIVE-BYTE")
                    )
                )
            )
        )


class DMATest(Module, AutoCSR):
    def __init__(self):

        self.start  = Signal()
        self.done   = Signal()
        self.len    = Signal(32)

        txbus = wishbone.Interface()
        rxbus = wishbone.Interface()
        self.submodules.txs = WishboneByteStreamTX(txbus)
        self.submodules.rxs = WishboneByteStreamRX(rxbus)

        self.comb += [
            self.txs.len.eq(self.len),
            self.rxs.len.eq(self.len),
            self.txs.start.eq(self.start),
            self.rxs.start.eq(self.start),
            self.done.eq(self.rxs.done),
            self.rxs.sink.data.eq(self.txs.source.data),
            self.rxs.sink.valid.eq(self.txs.source.valid),
            self.txs.source.ready.eq(self.rxs.sink.ready)
        ]

        # csr interface
        self._length  = CSRStorage(32)
        self._txadr   = CSRStorage(32)
        self._rxadr   = CSRStorage(32)
        self._control = CSRStorage(1)
        self._status  = CSRStorage(1)

        self.comb += [
            self.len.eq(self._length.storage),
            self.txs.adr.eq(self._txadr.storage[2:]),
            self.rxs.adr.eq(self._rxadr.storage[2:]),
            self.start.eq(self._control.storage[0]),
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
        self.master_bus = wishbone.Interface()
        self.submodules.arbiter = wishbone.Arbiter([txbus, rxbus], self.master_bus)


#
# unit tests
#

def _h(x):
    x = hex(x)[2:]
    x = "0"*(8-len(x)) + x
    return x


def _testbench_reader(dut, cnt, silent):
    yield dut.txs.bus.we.eq(0)
    yield dut.txs.adr.eq(0)
    yield dut.txs.len.eq(cnt)
    yield dut.txs.start.eq(1)
    yield
    yield dut.txs.start.eq(0)
    yield
    while not (yield dut.txs.done):
        if not silent:
            print("s=", (yield dut.txs.fsm.state),
                  "v=", (yield dut.txs.source.valid),
                  "r=", (yield dut.txs.source.ready),
                  "stb=", (yield dut.txs.bus.stb),
                  "ack=", (yield dut.txs.bus.ack),
            )
        if (yield dut.txs.source.valid):
            print("adr=", (yield dut.txs.bus.adr), "trlen=", (yield dut.txs.rdlen), "dat_r=", _h((yield dut.txs.bus.dat_r)), "data=", hex((yield dut.txs.source.data)))
            yield dut.txs.source.ready.eq(1)
        yield
        yield dut.txs.source.ready.eq(0)
    yield


def _testbench_writer(dut, cnt, silent):
    def write_byte(b):
        yield dut.rxs.sink.data.eq(b)
        yield dut.rxs.sink.valid.eq(1)
        while not (yield dut.rxs.sink.ready):
            if not silent:
                print("s=", (yield dut.rxs.fsm.state),
                      "a=", (yield dut.rxs.wradr),
                      "l=", (yield dut.rxs.wrlen),
                      "w=", _h((yield dut.rxs.word)),
                      "d=", (yield dut.rxs.sink.data),
                )
            yield
        yield dut.rxs.sink.valid.eq(0)
        yield

    yield dut.rxs.adr.eq(0)
    yield dut.rxs.len.eq(cnt)
    yield dut.rxs.start.eq(1)
    yield
    yield dut.rxs.start.eq(0)
    yield
    for i in range(cnt):
        yield from write_byte(i)
    yield


def _testbench1(dut):
    print("running testbench 1 ...")
    cnt = 5
    silent = True
    yield from _testbench_writer(dut, cnt, silent)
    yield from _testbench_reader(dut, cnt, silent)
    print("done.")


def _testbench_copy(dut, len):
    yield from dut.dma._length.write(len*4)
    yield from dut.dma._txadr.write(0x1000)
    yield from dut.dma._rxadr.write(0x2000)
    yield from dut.dma._control.write(1)
    yield
    while (yield from dut.dma._status.read()):
        yield
    for i in range(len):
        print(i, ":", hex((yield from dut.bus.read((0x2000>>2)+i))))


def _testbench2(dut):
    print("running testbench 2 ...")
    len = 20
    for i in range(len):
        yield from dut.bus.write((0x1000>>2)+i, i)
    yield from _testbench_copy(dut, len)
    print("(second run)")
    for i in range(len):
        yield from dut.bus.write((0x1000>>2)+i, ~i)
    yield from _testbench_copy(dut, len)
    print("done.")


if __name__ == "__main__":
    class _Dut1(Module):
        def __init__(self):
            self.submodules.txmem = wishbone.SRAM(1024)
            self.submodules.rxmem = wishbone.SRAM(self.txmem.mem)
            self.submodules.txs = WishboneByteStreamTX(self.txmem.bus)
            self.submodules.rxs = WishboneByteStreamRX(self.rxmem.bus)

    class _Dut2(Module):
        def __init__(self):
            self.submodules.txmem = wishbone.SRAM(1024)
            self.submodules.rxmem = wishbone.SRAM(1024)
            self.sysbus = wishbone.Interface()
            self.submodules.decoder = wishbone.Decoder(
                self.sysbus,
                [
                    (mem_decoder(0x1000, 1024), self.txmem.bus),
                    (mem_decoder(0x2000, 1024), self.rxmem.bus),
                ],
                register=True
            )
            self.bus = wishbone.Interface()
            self.submodules.dma = DMATest()
            self.submodules.arbiter = wishbone.Arbiter([self.bus, self.dma.master_bus], self.sysbus)

    dut1 = _Dut1()
    run_simulation(dut1, _testbench1(dut1), vcd_name="/tmp/test1.vcd")
    dut2 = _Dut2()
    run_simulation(dut2, _testbench2(dut2), vcd_name="/tmp/test2.vcd")
