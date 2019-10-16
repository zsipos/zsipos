#!/usr/bin/env python3

# This file is Copyright (c) 2018-2019 Florent Kermarrec <florent@enjoy-digital.fr>
# License: BSD

from os import getenv

from litex.boards.targets.nexys4ddr import *

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
        # SPI1
        spi1 = SPI(self.platform, "sdspi", number=1)
        self.submodules.spi1 = spi1
        self.add_wb_slave(self.mem_map["spi1"], spi1.bus, size=spi1.get_size())
        self.add_memory_region("spi1", self.mem_map["spi1"], spi1.get_size(), io_region=True)
        self.add_interrupt("spi1")
        # nexys4 special
        sdpwdn = self.platform.request("sdpwdn")
        self.comb += sdpwdn.eq(ResetSignal())
        #
        self.submodules.mmc = EXTINT(self.platform, "mmc")
        self.add_interrupt("mmc")
        # gpio
        gpio_signals = Cat(
            self.platform.request("user_led", 0),
            self.platform.request("user_led", 1),
            self.platform.request("user_led", 2),
            self.platform.request("user_led", 3))
        self.submodules.gpio = GPIOOut(gpio_signals)
        self.add_csr("gpio")
        # waveshare35a
        self.submodules.waveshare35a = EXTINT(self.platform, "waveshare35a")
        self.add_interrupt("waveshare35a")
        # AES
        aes = AES(self.platform)
        self.submodules.aes = aes
        self.add_wb_slave(self.mem_map["aes"], aes.bus, size=aes.get_size())
        self.add_memory_region("aes", self.mem_map["aes"], aes.get_size(), io_region=True)
        # SHA1
        sha1 = SHA1(self.platform)
        self.submodules.sha1 = sha1
        self.add_wb_slave(self.mem_map["sha1"], sha1.bus, size=sha1.get_size())
        self.add_memory_region("sha1", self.mem_map["sha1"], sha1.get_size(), io_region=True)

    def get_dts(self):
        d = DTSHelper(self)
        d.add_litex_uart(0, "uart")
        d.add_litex_eth (0, "ethphy", "ethmac")
        d.add_litex_gpio(0, "gpio", direction="out", ngpio=4)
        led_triggers = {
            0 : "activity",
        }
        d.add_gpio_leds(0, nleds=4, triggers=led_triggers)
        spi1devs = ""
        spi1devs += d.get_spi_mmc(0, "mmc")
        spi1devs += d.get_spi_waveshare35a(
            1,
            "waveshare35a",
            reset_gpio=(0, 1, 0),
            dc_gpio=(0, 2, 0),
            pendown_gpio=(0, 3, 0)
        )
        d.add_zsipos_spi(1, "spi", devices=spi1devs)
        d.add_zsipos_aes(0, "aes")
        d.add_zsipos_sha1(0, "sha1")
        s = self.cpu.build_dts(variant=d.get_cpu_variant(),
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
    soc = MySoC(sys_clk_freq=60e6,
                cpu_type="rocket"+getenv("BITS"),
                cpu_variant="linux",
                **soc_sdram_argdict(args))
    builder = Builder(soc, **builder_argdict(args))
    builder.build()
    if args.dts_file:
        soc.write_dts(args.dts_file)

if __name__ == "__main__":
    main()
