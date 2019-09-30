#!/usr/bin/env python3

# This file is Copyright (c) 2018-2019 Florent Kermarrec <florent@enjoy-digital.fr>
# License: BSD

import argparse

from migen import *

from litex.boards.targets.nexys4ddr import *

from litex.soc.integration.soc_sdram import *
from litex.soc.integration.builder import *

from litex.soc.cores.cpu.rocket2 import Rocket2RV64

from dts import *

# SoC ----------------------------------------------------------------------------------------------

class MySoC(EthernetSoC):

    def __init__(self, **kwargs):
        EthernetSoC.__init__(self, sys_clk_freq=60e6,
                             cpu_type="rocket2", cpu_variant="linux",
                             **kwargs)

    def get_dts(self):
        d = DTSHelper(self)
        d.add_litex_uart(0, "uart")
        d.add_litex_eth(0, "ethphy", "ethmac")
        s = Rocket2RV64.build_dts(variant=d.get_cpu_variant(),
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
    soc = MySoC(**soc_sdram_argdict(args))
    builder = Builder(soc, **builder_argdict(args))
    builder.build()
    if args.dts_file:
        soc.write_dts(args.dts_file)

if __name__ == "__main__":
    main()
