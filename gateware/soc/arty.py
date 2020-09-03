#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2018-2019 Florent Kermarrec <florent@enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause

# This file is Copyright (c) 2018-2019 Florent Kermarrec <florent@enjoy-digital.fr>
# License: BSD

from os import getenv

from litex.boards.targets.arty import *

from litex.soc.integration.soc_sdram import *
from litex.soc.integration.builder import *
from litex.soc.cores.gpio import *
from litex.soc.cores.spi_flash import SpiFlash

from flashmap import *

from tools.flash import *
from tools.dts import *

from cores.aes.aes_mod import AES
from cores.sha1.sha1_mod import SHA1
from cores.spi.spi_mod import SPI
from cores.interrupt.interrupt_mod import ExtInterrupt

# SoC ----------------------------------------------------------------------------------------------

class MySoC(EthernetSoC):
    mem_map = {
        "spiflash" : 0x20000000,
    }
    mem_map.update(EthernetSoC.mem_map)
    with_busmasters = False
    flash_size = 0x1000000

    def __init__(self, **kwargs):
        EthernetSoC.__init__(self, **kwargs)
        # flash-rom
        self.add_constant("FLASH_BOOT_ADDRESS", self.mem_map["spiflash"] + FLASH_BOOT_OFFSET)
        self.submodules.spiflash = SpiFlash(
            self.platform.request("spiflash4x"),
            dummy=11,
            div=2,
            with_bitbang=True,
            endianness=self.cpu.endianness)
        self.spiflash.add_clk_primitive(self.platform.device)
        self.add_wb_slave(self.mem_map["spiflash"], self.spiflash.bus, size=self.flash_size)
        self.add_memory_region("spiflash", self.mem_map["spiflash"], self.flash_size, type="io")
        self.add_csr("spiflash")

    def get_dts(self):
        if not hasattr(self.cpu, "build_dts"):
            return ""
        d = DTSHelper(self)
        d.add_litex_uart("uart")
        d.add_litex_eth ("ethphy", "ethmac")
        s = self.cpu.build_dts(bootargs="", devices=d.get_devices())
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
    flashhelper_args(parser)
    args = parser.parse_args()
    soc = MySoC(sys_clk_freq=int(60e6), **soc_sdram_argdict(args))
    builder = Builder(soc, **builder_argdict(args))
    builder.build()
    if args.dts_file:
        soc.write_dts(args.dts_file)
    if args.load:
        load_bistream(soc)
    if args.flash:
        load_flash(soc, FLASH_MAP)

if __name__ == "__main__":
    main()
