import os
from migen import *
from migen.fhdl.specials import Tristate
from litex.soc.interconnect import wishbone
from cores.interrupt.interrupt_mod import *

class SDCard(Module):
    def __init__(self, platform, name = "sdmmc", number=None):
        self.slave_bus  = slave  = wishbone.Interface()
        self.master_bus = master = wishbone.Interface()

        self.submodules.cmd_irq = Interrupt()
        self.submodules.dat_irq = Interrupt()

        self.cmd_wr = Signal()
        self.cmd_rd = Signal()
        self.cmd_oe = Signal()
        self.dat_wr = Signal(4)
        self.dat_rd = Signal(4)
        self.dat_oe = Signal()

        pads = platform.request(name, number)

        self.specials += Tristate(pads.cmd , o=self.cmd_wr, oe=self.cmd_oe, i=self.cmd_rd)
        self.specials += Tristate(pads.data, o=self.dat_wr, oe=self.dat_oe, i=self.dat_rd)

        slave_adr  = Signal(32)
        master_adr = Signal(32)

        self.comb += [
            slave_adr.eq(Cat(0,0, slave.adr)),
            master.adr.eq(master_adr[2:])
        ]

        self.specials += Instance("sdc_controller",
            # common
            i_wb_clk_i = ClockSignal(),
            i_wb_rst_i = ResetSignal(),
            # WISHBONE slave
            i_wb_dat_i = slave.dat_w,
            o_wb_dat_o = slave.dat_r,
            i_wb_adr_i = slave_adr,
            i_wb_sel_i = slave.sel,
            i_wb_we_i  = slave.we,
            i_wb_cyc_i = slave.cyc,
            i_wb_stb_i = slave.stb,
            o_wb_ack_o = slave.ack,
            # WISHBONE master
            o_m_wb_dat_o = master.dat_w,
            i_m_wb_dat_i = master.dat_r,
            o_m_wb_adr_o = master_adr,
            o_m_wb_sel_o = master.sel,
            o_m_wb_we_o  = master.we,
            o_m_wb_cyc_o = master.cyc,
            o_m_wb_stb_o = master.stb,
            i_m_wb_ack_i = master.ack,
            o_m_wb_cti_o = master.cti,
            o_m_wb_bte_o = master.bte,
            # interrupts
            o_int_cmd  = self.cmd_irq.ev.irq,
            o_int_data = self.dat_irq.ev.irq,
            # SD BUS
            i_sd_cmd_dat_i = self.cmd_rd,
            o_sd_cmd_out_o = self.cmd_wr,
            o_sd_cmd_oe_o  = self.cmd_oe,
            i_sd_dat_dat_i = self.dat_rd,
            o_sd_dat_out_o = self.dat_wr,
            o_sd_dat_oe_o  = self.dat_oe,
            o_sd_clk_o_pad = pads.clk,
            i_sd_clk_i_pad = ClockSignal()
        )

        # add sources
        dir = os.path.join(os.path.abspath(os.path.dirname(__file__)), "verilog", "rtl", "verilog")
        platform.add_source_dir(dir)
        platform.add_verilog_include_path(dir)

    def get_size(self):
        return 0x1000