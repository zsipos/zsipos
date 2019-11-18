import os
from migen import *
from litex.soc.interconnect import wishbone

class SHA1(Module):

    def __init__(self, platform):

        self.bus = bus = wishbone.Interface()

        address = Signal(8)
        reset_n = Signal(1)
        cs      = Signal(1)

        self.comb += [
            address.eq(bus.adr[0:7]),
            reset_n.eq(~ResetSignal()),
            cs.eq(bus.cyc & bus.stb)
        ]

        self.sync += bus.ack.eq(cs & ~bus.ack)

        self.specials += Instance("sha1",
            i_clk        = ClockSignal(),
            i_reset_n    = reset_n,
            i_cs         = cs,
            i_we         = bus.we,
            i_address    = address,
            i_write_data = bus.dat_w,
            o_read_data  = bus.dat_r
        )

        # add sources
        dir=os.path.join(os.path.abspath(os.path.dirname(__file__)), "verilog", "src", "rtl")
        platform.add_source_dir(dir)

    def get_size(self):
        return 0x1000