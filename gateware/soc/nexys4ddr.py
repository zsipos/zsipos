#!/usr/bin/env python3

# This file is Copyright (c) 2018-2019 Florent Kermarrec <florent@enjoy-digital.fr>
# License: BSD

from os import getenv

from litex.boards.targets.nexys4ddr import *

from litex.soc.integration.soc_sdram import *
from litex.soc.integration.builder import *
from litex.soc.cores.gpio import *
from litex.soc.cores.spi_flash import SpiFlash

from flashmap import *

from tools.dts import *
from tools.flash import *

from cores.aes.aes_mod import AES
from cores.sha1.sha1_mod import SHA1
from cores.spim.spim_mod import SPIMaster
from cores.sdcard.sdcard_mod import SDCard

from cores.utils.wishbone import DMATest

# SoC ----------------------------------------------------------------------------------------------

class MySoC(EthernetSoC):
    mem_map = {
        "spiflash" : 0x40000000,
        "spim"     : 0x41000000,
        "aes"      : 0x42000000,
        "sha1"     : 0x43000000,
        "sdmmc"    : 0x44000000,
    }
    mem_map.update(EthernetSoC.mem_map)
    with_busmasters = True
    flash_size = 0x1000000
    fast_sd = True

    def __init__(self, **kwargs):
        EthernetSoC.__init__(self, **kwargs)
        # flash-rom
        self.add_constant("FLASH_BOOT_ADDRESS", self.mem_map["spiflash"]+FLASH_BOOT_OFFSET)
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
        # sd-card
        if self.fast_sd:
            self.submodules.sdmmc = SDCard(self.platform, "sdmmc")
            self.add_wb_master(self.sdmmc.master_bus)
            self.add_wb_slave(self.mem_map["sdmmc"], self.sdmmc.slave_bus, size=self.sdmmc.get_size())
            self.add_memory_region("sdmmc", self.mem_map["sdmmc"], self.sdmmc.get_size(), type="io")
            self.sdmmc_cmd_irq = self.sdmmc.cmd_irq
            self.sdmmc_dat_irq = self.sdmmc.dat_irq
            self.add_interrupt("sdmmc_cmd_irq")
            self.add_interrupt("sdmmc_dat_irq")
        else:
            self.submodules.spim = SPIMaster(self.platform, name="sdspi", busmaster=False)
            if hasattr(self.spim, "master_bus"):
                self.add_wb_master(self.spim.master_bus)
            self.add_wb_slave(self.mem_map["spim"], self.spim.slave_bus, size=self.spim.get_size())
            self.add_memory_region("spim", self.mem_map["spim"], self.spim.get_size(), type="io")
            self.add_csr("spim")
            self.add_interrupt("spim")
        # nexys4 special
        sdpwdn = self.platform.request("sdpwdn")
        self.comb += sdpwdn.eq(ResetSignal())
        # gpio
        gpio0_signals = Cat(
            self.platform.request("user_led", 0),
            self.platform.request("user_led", 1),
            self.platform.request("user_led", 2),
            self.platform.request("user_led", 3))
        self.submodules.gpio0 = GPIOOut(gpio0_signals)
        self.add_csr("gpio0")
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
        # test
        self.submodules.dmatest = DMATest()
        self.add_wb_master(self.dmatest.master_bus)
        self.add_csr("dmatest")


    def get_dts(self):
        d = DTSHelper(self)
        d.print_csr_offsets(["dmatest"])
        d.add_litex_uart("uart")
        d.add_litex_eth ("ethphy", "ethmac")
        d.add_litex_gpio("gpio0", direction="out", ngpio=4)
        led_triggers = {
            0: "activity",
            1: "cpu0",
            2: "cpu1"
        }
        d.add_gpio_leds("gpio0", nleds=4, triggers=led_triggers)
        if self.fast_sd:
            d.add_opencores_sdc("sdmmc")
        else:
            d.add_zsipos_spim("spim", devices=d.get_spi_mmc(0, "mmc"))
        d.add_zsipos_aes("aes")
        d.add_zsipos_sha1("sha1")
        d.add_zsipos_dmatest("dmatest")
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
        load_flash(soc, FLASH_MAP)


if __name__ == "__main__":
    main()
