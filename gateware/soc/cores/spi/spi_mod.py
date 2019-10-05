import os

from migen import *

from litex.soc.interconnect import wishbone

class IRQ():
    def __init__(self):
        self.irq = Signal(1)


class SPI(Module):

    def __init__(self, platform, name = "spi", number=None, ss_width = 1):

        pads = platform.request(name, number)

        self.bus = bus = wishbone.Interface()
        self.ev  = IRQ()

        adri = Signal(3)
        dati = Signal(8)
        dato = Signal(8)

        self.comb += [
            adri.eq(bus.adr[1:4]),
            dati.eq(bus.dat_w[0:8]),
            bus.dat_r.eq(Cat(dato, Replicate(0, 24)))
        ]

        platform.add_sources(
            os.path.join(os.path.abspath(os.path.dirname(__file__)), "verilog"),
            "spi_top.v",
            "spi_fifo.v"
        )

        self.specials +=  Instance("zsipos_spi",
            p_SS_WIDTH = ss_width,
            i_clk_i    = ClockSignal(),
            i_rst_i    = ResetSignal(),
            i_cyc_i    = bus.cyc,
            i_stb_i    = bus.stb,
            i_adr_i    = adri,
            i_we_i     = bus.we,
            i_dat_i    = dati,
            o_dat_o    = dato,
            o_ack_o    = bus.ack,
            o_inta_o   = self.ev.irq,
            o_sck_o    = pads.sclk,
            o_ss_o     = pads.ss_n,
            o_mosi_o   = pads.mosi,
            i_miso_i   = pads.miso
        )

    def get_size(self):
        return 0x1000