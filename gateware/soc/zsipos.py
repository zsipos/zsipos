#!/usr/bin/env python3

import argparse

from os import getenv

from litex.soc.cores.clock import *
from litex.soc.cores.gpio import *
from litex.soc.integration.soc_sdram import *
from litex.soc.integration.builder import *

from litedram.modules import IM4G08D3FABG125
from litedram.phy import s7ddrphy

from liteeth.phy.mii import LiteEthPHYMII
from liteeth.mac import LiteEthMAC

from platform import Platform
from dts import *

from cores.aes.aes_mod import AES
from cores.sha1.sha1_mod import SHA1
from cores.spi.spi_mod import SPI
from cores.extint.extint_mod import EXTINT

# CRG ----------------------------------------------------------------------------------------------

class _CRG(Module):
    def __init__(self, platform, sys_clk_freq):
        self.clock_domains.cd_sys = ClockDomain()
        self.clock_domains.cd_sys4x = ClockDomain(reset_less=True)
        self.clock_domains.cd_sys4x_dqs = ClockDomain(reset_less=True)
        self.clock_domains.cd_clk200 = ClockDomain()

        # # #

        self.cd_sys.clk.attr.add("keep")
        self.cd_sys4x.clk.attr.add("keep")
        self.cd_sys4x_dqs.clk.attr.add("keep")

        self.submodules.pll = pll = S7MMCM(speedgrade=-2)

        self.comb += pll.reset.eq(platform.request("cpu_reset"))

        pll.register_clkin(platform.request("clk100"), 100e6)
        pll.create_clkout(self.cd_sys, sys_clk_freq)
        pll.create_clkout(self.cd_sys4x, 4*sys_clk_freq)
        pll.create_clkout(self.cd_sys4x_dqs, 4*sys_clk_freq, phase=90)
        pll.create_clkout(self.cd_clk200, 200e6)

        self.submodules.idelayctrl = S7IDELAYCTRL(self.cd_clk200)

# BaseSoC ------------------------------------------------------------------------------------------

class BaseSoC(SoCSDRAM):
    def __init__(self, sys_clk_freq=int(75e6), **kwargs):
        platform = Platform()
        SoCSDRAM.__init__(self, platform, clk_freq=sys_clk_freq,
                          integrated_rom_size=0x8000,
                          integrated_sram_size=0x8000,
                          l2_size=0, **kwargs)

        self.submodules.crg = _CRG(platform, sys_clk_freq)

        # sdram
        self.submodules.ddrphy = s7ddrphy.A7DDRPHY(platform.request("ddram"), sys_clk_freq=sys_clk_freq)
        self.add_csr("ddrphy")
        sdram_module = IM4G08D3FABG125(sys_clk_freq, "1:4")
        self.register_sdram(self.ddrphy,
                            sdram_module.geom_settings,
                            sdram_module.timing_settings)

# EthernetSoC --------------------------------------------------------------------------------------

class EthernetSoC(BaseSoC):
    mem_map = {
        "ethmac"  : 0x30000000,
        "ethmac1" : 0x31000000,
    }
    mem_map.update(BaseSoC.mem_map)

    def __init__(self, **kwargs):
        BaseSoC.__init__(self, **kwargs)

        self.submodules.ethphy = LiteEthPHYMII(self.platform.request("eth_clocks", 0),
                                               self.platform.request("eth", 0))
        self.add_csr("ethphy")
        self.submodules.ethmac = LiteEthMAC(phy=self.ethphy, dw=32,
            interface="wishbone", endianness=self.cpu.endianness)
        self.add_wb_slave(self.mem_map["ethmac"], self.ethmac.bus, 0x2000)
        self.add_memory_region("ethmac", self.mem_map["ethmac"], 0x2000, type="io")
        self.add_csr("ethmac")
        self.add_interrupt("ethmac")

        self.ethphy.crg.cd_eth_rx.clk.attr.add("keep")
        self.ethphy.crg.cd_eth_tx.clk.attr.add("keep")
        self.platform.add_period_constraint(self.ethphy.crg.cd_eth_rx.clk, 1e9/25e6)
        self.platform.add_period_constraint(self.ethphy.crg.cd_eth_tx.clk, 1e9/25e6)
        self.platform.add_false_path_constraints(
            self.crg.cd_sys.clk,
            self.ethphy.crg.cd_eth_rx.clk,
            self.ethphy.crg.cd_eth_tx.clk)

        pwdn = self.platform.request("eth_pwdn", 0)
        self.comb += pwdn.eq(1)

        self.submodules.ethphy1 = LiteEthPHYMII(self.platform.request("eth_clocks", 1),
                                                self.platform.request("eth", 1))
        self.add_csr("ethphy1")
        self.submodules.ethmac1 = LiteEthMAC(phy=self.ethphy1, dw=32,
                                             interface="wishbone", endianness=self.cpu.endianness)
        self.add_wb_slave(self.mem_map["ethmac1"], self.ethmac1.bus, 0x2000)
        self.add_memory_region("ethmac1", self.mem_map["ethmac1"], 0x2000, type="io")
        self.add_csr("ethmac1")
        self.add_interrupt("ethmac1")

        self.ethphy1.crg.cd_eth_rx.clk.attr.add("keep")
        self.ethphy1.crg.cd_eth_tx.clk.attr.add("keep")
        self.platform.add_period_constraint(self.ethphy1.crg.cd_eth_rx.clk, 1e9 / 25e6)
        self.platform.add_period_constraint(self.ethphy1.crg.cd_eth_tx.clk, 1e9 / 25e6)
        self.platform.add_false_path_constraints(
            self.crg.cd_sys.clk,
            self.ethphy1.crg.cd_eth_rx.clk,
            self.ethphy1.crg.cd_eth_tx.clk)

        pwdn1 = self.platform.request("eth_pwdn", 1)
        self.comb += pwdn1.eq(1)


class MySoC(EthernetSoC):
    mem_map = {
        "spi"  : 0x41000000,
        "spi1" : 0x42000000,
        "aes"  : 0x4e000000,
        "sha1" : 0x4f000000,
    }
    mem_map.update(EthernetSoC.mem_map)
    with_busmasters = False

    def __init__(self, **kwargs):
        EthernetSoC.__init__(self, **kwargs)
        # SPI0: sd-card
        spi = SPI(self.platform, "sd_spi")
        self.submodules.spi = spi
        self.add_wb_slave(self.mem_map["spi"], spi.bus, size=spi.get_size())
        self.add_memory_region("spi", self.mem_map["spi"], spi.get_size(), type="io")
        self.add_interrupt("spi")
        # SPI1: waveshare35a
        spi1 = SPI(self.platform, "ws35a_spi", ss_width=2)
        self.submodules.spi1 = spi1
        self.add_wb_slave(self.mem_map["spi1"], spi1.bus, size=spi1.get_size())
        self.add_memory_region("spi1", self.mem_map["spi1"], spi1.get_size(), type="io")
        self.add_interrupt("spi1")
        # waveshare35a
        ws35a_rs    = Signal()
        ws35a_reset = Signal()
        self.submodules.ws35a = EXTINT(self.platform, "ws35a_int")
        self.add_interrupt("ws35a")
        # gpio0: leds, ws35a controls
        gpio_signals = Cat(
            self.platform.request("user_led", 0),
            self.platform.request("user_led", 1),
            self.platform.request("user_led", 2),
            self.platform.request("user_led", 3),
            ws35a_rs,
            ws35a_reset)
        self.submodules.gpio = GPIOOut(gpio_signals)
        self.add_csr("gpio")
        # gpio1: touchscreen pendown
        gpio1_signals = Cat(self.ws35a.ev.irq)
        self.submodules.gpio1 = GPIOIn(gpio1_signals)
        self.add_csr("gpio1")
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
        d.add_litex_uart(0, "uart")
        d.add_litex_eth(0, "ethphy", "ethmac")
        d.add_litex_eth(1, "ethphy", "ethmac")
        d.add_litex_gpio(0, "gpio", direction="out", ngpio=6)
        led_triggers = {
            0: "activity",
            1: "cpu0",
            2: "cpu1"
        }
        d.add_gpio_leds(0, nleds=4, triggers=led_triggers)
        d.add_litex_gpio(1, "gpio", direction="in", ngpio=1)
        spidevs = d.get_spi_mmc(0, "mmc")
        d.add_zsipos_spi(0, "spi", devices=spidevs)
        spi1devs = d.get_spi_waveshare35a(
            1,
            "ws35a",
            dc_gpio=(0, 4, 0),
            reset_gpio=(0, 5, 0),
            pendown_gpio=(1, 0, 0)
        )
        d.add_zsipos_spi(1, "spi", devices=spi1devs)
        d.add_zsipos_aes(0, "aes")
        d.add_zsipos_sha1(0, "sha1")
        s = self.cpu.build_dts(devices=d.get_devices())
        return s

    def write_dts(self, dts_file):
        with open(dts_file, "w") as f:
            f.write(self.get_dts())

# Build --------------------------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(description="LiteX SoC on ZSIPOS")
    builder_args(parser)
    soc_sdram_args(parser)
    dtshelper_args(parser)
    args = parser.parse_args()
    soc = MySoC(sys_clk_freq=int(75e6), **soc_sdram_argdict(args))
    builder = Builder(soc, **builder_argdict(args))
    builder.build()
    if args.dts_file:
        soc.write_dts(args.dts_file)

if __name__ == "__main__":
    main()
