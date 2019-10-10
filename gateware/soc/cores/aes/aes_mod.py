import os
from migen import *
from litex.soc.interconnect import wishbone

class AES(Module):

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

        If(cs, bus.ack.eq(1)).Elif(bus.ack, bus.ack.eq(0))

        platform.add_sources(
            os.path.join(os.path.abspath(os.path.dirname(__file__)), "verilog", "src", "rtl"),
            "aes.v",
            "aes_core.v",
            "aes_decipher_block.v",
            "aes_encipher_block.v",
            "aes_inv_sbox.v",
            "aes_key_mem.v",
            "aes_sbox.v"
        )

        self.specials += Instance("aes",
            i_clk        = ClockSignal(),
            i_reset_n    = reset_n,
            i_cs         = cs,
            i_we         = bus.we,
            i_address    = address,
            i_write_data = bus.dat_w,
            o_read_data  = bus.dat_r
        )

    def get_size(self):
        return 0x1000