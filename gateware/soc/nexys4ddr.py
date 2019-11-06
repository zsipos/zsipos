#!/usr/bin/env python3

# This file is Copyright (c) 2018-2019 Florent Kermarrec <florent@enjoy-digital.fr>
# License: BSD

from os import getenv

from litex.boards.targets.nexys4ddr import *

from litex.soc.integration.soc_sdram import *
from litex.soc.integration.builder import *
from litex.soc.cores.gpio import *
from litex.soc.cores.spi_flash import SpiFlash

from dts import *
from flash import *

from cores.aes.aes_mod import AES
from cores.sha1.sha1_mod import SHA1
from cores.spi.spi_mod import SPI
from cores.spim.spim_mod import SPIMaster
from cores.extint.extint_mod import EXTINT

# SoC ----------------------------------------------------------------------------------------------

class MySoC(EthernetSoC):
    mem_map = {
        "spim"     : 0x41000000,
        "aes"      : 0x42000000,
        "sha1"     : 0x43000000,
        "spiflash" : 0x50000000,
    }
    mem_map.update(EthernetSoC.mem_map)
    with_busmasters = False

    def __init__(self, **kwargs):
        EthernetSoC.__init__(self, **kwargs)
        # flash-rom
        flash_size = 0x10000000
        self.submodules.spiflash = SpiFlash(
            self.platform.request("spiflash4x"),
            dummy=11,
            div=2,
            with_bitbang=True,
            endianness=self.cpu.endianness)
        self.spiflash.add_clk_primitive(self.platform.device)
        self.add_wb_slave(self.mem_map["spiflash"], self.spiflash.bus, size=flash_size)
        self.add_memory_region("spiflash", self.mem_map["spiflash"], flash_size, type="io")
        self.add_csr("spiflash")
        # sd-card
        self.submodules.spim = SPIMaster(self.platform.request("sdspi"), busmaster=self.with_busmasters)
        if self.with_busmasters:
            self.add_wb_master(self.spim.master_bus)
        self.add_wb_slave(self.mem_map["spim"], self.spim.slave_bus, size=self.spim.get_size())
        self.add_memory_region("spim", self.mem_map["spim"], self.spim.get_size(), type="io")
        self.add_csr("spim")
        self.add_interrupt("spim")
        # nexys4 special
        sdpwdn = self.platform.request("sdpwdn")
        self.comb += sdpwdn.eq(ResetSignal())
        # gpio
        gpio_signals = Cat(
            self.platform.request("user_led", 0),
            self.platform.request("user_led", 1),
            self.platform.request("user_led", 2),
            self.platform.request("user_led", 3))
        self.submodules.gpio = GPIOOut(gpio_signals)
        self.add_csr("gpio")
        # AES
        aes = AES(self.platform)
        self.submodules.aes = aes
        self.add_wb_slave(self.mem_map["aes"], aes.bus, size=aes.get_size())
        self.add_memory_region("aes", self.mem_map["aes"], aes.get_size(), type="io")
        # SHA1
        sha1 = SHA1(self.platform)
        self.submodules.sha1 = sha1
        self.add_wb_slave(self.mem_map["sha1"], sha1.bus, size=sha1.get_size())
        self.add_memory_region("sha1", self.mem_map["sha1"], sha1.get_size(), type="io")

    def get_dts(self):
        d = DTSHelper(self)
        d.print_csr_offsets(["spim"])
        d.add_litex_uart(0, "uart")
        d.add_litex_eth (0, "ethphy", "ethmac")
        d.add_litex_gpio(0, "gpio", direction="out", ngpio=4)
        led_triggers = {
            0: "activity",
            1: "cpu0",
            2: "cpu1"
        }
        d.add_gpio_leds(0, nleds=4, triggers=led_triggers)
        d.add_zsipos_spim(0, "spim", devices=d.get_spi_mmc(0, "mmc"))
        d.add_zsipos_aes(0, "aes")
        d.add_zsipos_sha1(0, "sha1")
        s = self.cpu.build_dts(devices=d.get_devices())
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
        load_flash(soc)


if __name__ == "__main__":
    main()
