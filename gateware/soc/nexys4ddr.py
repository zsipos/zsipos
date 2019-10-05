#!/usr/bin/env python3

# This file is Copyright (c) 2018-2019 Florent Kermarrec <florent@enjoy-digital.fr>
# License: BSD

import argparse

from migen import *

from litex.boards.targets.nexys4ddr import *

from litex.soc.integration.soc_sdram import *
from litex.soc.integration.builder import *

from litex.soc.cores.cpu.rocket2 import Rocket64

from dts import *

from cores.spi.spi_mod import SPI
from cores.extint.extint_mod import EXTINT

# SoC ----------------------------------------------------------------------------------------------

class MySoC(EthernetSoC):

    mem_map = {
        "spi1": 0x20000000,  # (shadow @0xa0000000)
    }
    mem_map.update(EthernetSoC.mem_map)

    def __init__(self, **kwargs):
        EthernetSoC.__init__(self, **kwargs)
        spi1 = SPI(self.platform, "sdspi", number=1)
        self.submodules.spi1 = spi1
        self.add_wb_slave(self.mem_map["spi1"], spi1.bus, size=spi1.get_size())
        self.add_memory_region("spi1", self.mem_map["spi1"] | self.shadow_base, spi1.get_size())
        self.add_interrupt("spi1")
        # nexys4 special
        sdpwdn = self.platform.request("sdpwdn")
        self.comb += sdpwdn.eq(ResetSignal())
        #
        self.submodules.mmc = EXTINT(self.platform, "mmc")
        self.add_interrupt("mmc")

    def get_dts(self):
        d = DTSHelper(self)
        d.add_litex_uart(0, "uart")
        d.add_litex_eth (0, "ethphy", "ethmac")
        d.add_zsipos_spi(1, "spi", devices=d.get_spi_mmc(0, "mmc"))
        s = Rocket64.build_dts(variant=d.get_cpu_variant(),
                               bootargs="",
                               sdram_size=d.get_sdram_size(),
                               timebase_frequency=d.get_sys_clk_freq()//100,
                               devices=d.get_devices())
        return s

    def write_dts(self, dts_file):
        with open(dts_file, "w") as f:
            f.write(self.get_dts())

# Build --------------------------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(description="LiteX SoC on Nexys4DDR")
    builder_args(parser)
    soc_sdram_args(parser)
    dtshelper_args(parser)
    args = parser.parse_args()
    soc = MySoC(sys_clk_freq=60e6, cpu_type="rocket64", cpu_variant="linux", **soc_sdram_argdict(args))
    builder = Builder(soc, **builder_argdict(args))
    builder.build()
    if args.dts_file:
        soc.write_dts(args.dts_file)

if __name__ == "__main__":
    main()
