#!/usr/bin/env python3

# This file is Copyright (c) 2018-2019 Florent Kermarrec <florent@enjoy-digital.fr>
# License: BSD

from os import getenv

from litex.boards.targets.arty import *

from litex.soc.integration.soc_sdram import *
from litex.soc.integration.builder import *
from litex.soc.cores.gpio import *

from dts import *

from cores.aes.aes_mod import AES
from cores.sha1.sha1_mod import SHA1
from cores.spi.spi_mod import SPI
from cores.extint.extint_mod import EXTINT

# SoC ----------------------------------------------------------------------------------------------

class MySoC(EthernetSoC):
    mem_map = {
        "spi1": 0x41000000,
        "aes":  0x42000000,
        "sha1": 0x43000000,
    }
    mem_map.update(EthernetSoC.mem_map)
    no_wishbone_sdram = True

    def __init__(self, **kwargs):
        EthernetSoC.__init__(self, **kwargs)

    def get_dts(self):
        d = DTSHelper(self)
        d.add_litex_uart(0, "uart")
        d.add_litex_eth (0, "ethphy", "ethmac")
        s = self.cpu.build_dts(bootargs="",
                               sdram_size=d.get_sdram_size(),
                               timebase_frequency=d.get_sys_clk_freq()//100,
                               devices=d.get_devices())
        return s

    def write_dts(self, dts_file):
        with open(dts_file, "w") as f:
            f.write(self.get_dts())

# Build --------------------------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(description="LiteX SoC on Arty")
    builder_args(parser)
    soc_sdram_args(parser)
    dtshelper_args(parser)
    args = parser.parse_args()
    soc = MySoC(sys_clk_freq=int(60e6), **soc_sdram_argdict(args))
    builder = Builder(soc, **builder_argdict(args))
    builder.build()
    if args.dts_file:
        soc.write_dts(args.dts_file)

if __name__ == "__main__":
    main()
