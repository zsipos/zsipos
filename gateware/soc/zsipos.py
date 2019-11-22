#!/usr/bin/env python3

import argparse

from os import getenv

from litex.soc.cores.clock import *
from litex.soc.cores.gpio import *
from litex.soc.cores.spi_flash import SpiFlash

from litex.soc.integration.soc_sdram import *
from litex.soc.integration.builder import *

from litedram.modules import IM4G08D3FABG125
from litedram.phy import s7ddrphy

from liteeth.phy.mii import LiteEthPHYMII
from liteeth.mac import LiteEthMAC

from platforms import zsipos

from flashmap import *

from tools.flash import *
from tools.dts import *

from cores.aes.aes_mod import AES
from cores.sha1.sha1_mod import SHA1
from cores.sdcard.sdcard_mod import SDCard
#from cores.spim.spim_mod import SPIMaster
from cores.spi.spi_mod import SPIMaster
from cores.interrupt.interrupt_mod import Interrupt

# CRG ----------------------------------------------------------------------------------------------

class _CRG(Module):
    def __init__(self, platform, sys_clk_freq, clock_reset):
        self.clock_domains.cd_sys = ClockDomain()
        self.clock_domains.cd_sys4x = ClockDomain(reset_less=True)
        self.clock_domains.cd_sys4x_dqs = ClockDomain(reset_less=True)
        self.clock_domains.cd_clk200 = ClockDomain()

        # # #

        self.cd_sys.clk.attr.add("keep")
        self.cd_sys4x.clk.attr.add("keep")
        self.cd_sys4x_dqs.clk.attr.add("keep")

        self.submodules.pll = pll = S7MMCM(speedgrade=-2)

        self.comb += pll.reset.eq(clock_reset)

        pll.register_clkin(platform.request("clk100"), 100e6)
        pll.create_clkout(self.cd_sys, sys_clk_freq)
        pll.create_clkout(self.cd_sys4x, 4*sys_clk_freq)
        pll.create_clkout(self.cd_sys4x_dqs, 4*sys_clk_freq, phase=90)
        pll.create_clkout(self.cd_clk200, 200e6)

        self.submodules.idelayctrl = S7IDELAYCTRL(self.cd_clk200)

# BaseSoC ------------------------------------------------------------------------------------------

class BaseSoC(SoCSDRAM):
    def __init__(self, sys_clk_freq=int(75e6), **kwargs):
        platform = zsipos.Platform()
        SoCSDRAM.__init__(self, platform, clk_freq=sys_clk_freq,
                          integrated_rom_size=0x8000,
                          integrated_sram_size=0x8000,
                          l2_size=0, **kwargs)

        # clock_reset is top level reset
        clock_reset = Signal()
        self.submodules.crg = _CRG(platform, sys_clk_freq, clock_reset)

        # reset logic for logic triggered reset
        # soc.reset can be used e.g. for gpio reset
        self.reset = Signal()
        if self.full_board:
            self.comb += clock_reset.eq((self.reset & self.crg.pll.locked) | ~platform.request("cpu_reset"))
        else:
            self.comb += clock_reset.eq((self.reset & self.crg.pll.locked) | platform.request("reset_trenz"))
            print("using settings for te0710 only")

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

        self.submodules.ethphy = LiteEthPHYMII(self.platform.request("eth_clocks"),
                                               self.platform.request("eth"))
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
                                                self.platform.request("eth", 1),
                                                with_hw_init_reset=False)
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


class TouchscreenInterrupt(Interrupt):
    def __init__(self, pin):
        Interrupt.__init__(self)
        pin_last = Signal(reset=1)
        self.sync += [
            If(pin != pin_last,
                pin_last.eq(pin),
                self.ev.irq.eq(~pin)
            ).Else(
                self.ev.irq.eq(0)
            )
        ]


class MySoC(EthernetSoC):
    mem_map = {
        "sdmmc"    : 0x40000000,
        "spi0"     : 0x41000000,
        "spi1"     : 0x42000000,
        "aes"      : 0x4e000000,
        "sha1"     : 0x4f000000,
        "spiflash" : 0x50000000,
    }
    mem_map.update(EthernetSoC.mem_map)
    flash_size = 0x2000000
    with_busmasters = True
    full_board = True
    fast_sd = False

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
        if self.full_board:
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
                # SPI0: sd-card
                self.submodules.spi0 = SPIMaster(self.platform, name="sdspi", busmaster=False)
                if hasattr(self.spi0, "master_bus"):
                    self.add_wb_master(self.spi0.master_bus)
                self.add_wb_slave(self.mem_map["spi0"], self.spi0.slave_bus, size=self.spi0.get_size())
                self.add_memory_region("spi0", self.mem_map["spi0"], self.spi0.get_size(), type="io")
                self.add_csr("spi0")
                self.add_interrupt("spi0")
            # SPI1: waveshare35a
            self.submodules.spi1 = SPIMaster(self.platform, name="ws35a_spi", cs_width=2, busmaster=False)
            if hasattr(self.spi1, "master_bus"):
                self.add_wb_master((self.spi1.master_bus))
            self.add_wb_slave(self.mem_map["spi1"], self.spi1.slave_bus, size=self.spi1.get_size())
            self.add_memory_region("spi1", self.mem_map["spi1"], self.spi1.get_size(), type="io")
            self.add_csr("spi1")
            self.add_interrupt("spi1")
            # waveshare35a
            ws35a_rs      = self.platform.request("ws35a_rs")
            ws35a_reset   = self.platform.request("ws35a_reset")
            ws35a_pendown = self.platform.request("ws35a_int")
            self.submodules.ws35a = TouchscreenInterrupt(ws35a_pendown)
            self.add_interrupt("ws35a")
            # gpio0: leds, ws35a controls
            board_led = Signal()
            self.comb += self.platform.request("board_led").eq(~board_led)
            gpio0_signals = Cat(
                self.platform.request("user_led", 0),
                self.platform.request("user_led", 1),
                self.platform.request("user_led", 2),
                self.platform.request("user_led", 3),
                board_led,
                self.reset,
                ws35a_rs,
                ws35a_reset,
            )
            self.submodules.gpio0 = GPIOOut(gpio0_signals)
            self.add_csr("gpio0")
            # gpio1: touchscreen pendown
            gpio1_signals = Cat(ws35a_pendown)
            self.submodules.gpio1 = GPIOIn(gpio1_signals)
            self.add_csr("gpio1")
            # AES
            self.submodules.aes = AES(self.platform)
            self.add_wb_slave(self.mem_map["aes"], self.aes.bus, size=self.aes.get_size())
            self.add_memory_region("aes", self.mem_map["aes"], self.aes.get_size(), type="io")
            # SHA1
            self.submodules.sha1 = SHA1(self.platform)
            self.add_wb_slave(self.mem_map["sha1"], self.sha1.bus, size=self.sha1.get_size())
            self.add_memory_region("sha1", self.mem_map["sha1"], self.sha1.get_size(), type="io")


    def get_dts(self):
        d = DTSHelper(self)
        d.add_litex_uart("uart")
        d.add_litex_eth("ethphy", "ethmac")
        d.add_litex_eth("ethphy1", "ethmac1")
        if self.full_board:
            d.add_litex_gpio("gpio0", direction="out", ngpio=8)
            led_triggers = {
                0: "activity",
                1: "cpu0",
                2: "cpu1",
                4: "heartbeat"
            }
            d.add_gpio_leds("gpio0", nleds=5, triggers=led_triggers)
            d.add_gpio_restart("gpio0", 5)
            d.add_litex_gpio("gpio1", direction="in", ngpio=1)
            if self.fast_sd:
                d.add_opencores_sdc("sdmmc")
            else:
                spidevs = d.get_spi_mmc(0, "mmc")
                d.add_zsipos_spi("spi0", devices=spidevs)
            spi1devs = d.get_spi_waveshare35a(
                0,
                "ws35a",
                dc_gpio=("gpio0", 6, 0),
                reset_gpio=("gpio0", 7, 0),
                pendown_gpio=("gpio1", 0, 0)
            )
            d.add_zsipos_spi("spi1", devices=spi1devs)
            d.add_zsipos_aes("aes")
            d.add_zsipos_sha1("sha1")
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
    flashhelper_args(parser)
    args = parser.parse_args()
    soc = MySoC(sys_clk_freq=int(75e6), **soc_sdram_argdict(args))
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
