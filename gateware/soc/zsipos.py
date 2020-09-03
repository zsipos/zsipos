#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2019 Stefan Adams <stefan.adams@vipcomag.de>
# SPDX-License-Identifier: GPL-3.0-or-later

import argparse

from os import getenv

from litex.soc.cores.clock import *
from litex.soc.cores.gpio import GPIOIn, GPIOOut
from litex.soc.cores.spi_flash import SpiFlash
from litex.soc.cores.timer import Timer

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
from cores.spi.spi_mod import SPIMaster
from cores.interrupt.interrupt_mod import Interrupt
from cores.memirq.memirq_mod import MemIrq
from cores.utils.wishbone import DMATest

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
        SoCSDRAM.__init__(self, platform, clk_freq=sys_clk_freq, **kwargs)

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
        self.add_memory_region("ethmac", self.mem_map["ethmac"], 0x2000, type="io")
        self.add_wb_slave(self.mem_map["ethmac"], self.ethmac.bus, 0x2000)
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
        self.add_memory_region("ethmac1", self.mem_map["ethmac1"], 0x2000, type="io")
        self.add_wb_slave(self.mem_map["ethmac1"], self.ethmac1.bus, 0x2000)
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
            self.ev.irq.eq(0),
            If(pin != pin_last,
                pin_last.eq(pin),
                If(~pin, self.ev.irq.eq(1))
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
    with_busmasters = False
    full_board = True
    fast_sd = with_busmasters and False

    def __init__(self, **kwargs):
        EthernetSoC.__init__(self, **kwargs)
        self.set_bios_ip("192.168.0.55", "192.168.0.45")
        # flash-rom
        self.add_constant("FLASH_BOOT_ADDRESS", self.mem_map["spiflash"] + FLASH_BOOTROM_OFFSET)
        self.submodules.spiflash = SpiFlash(
            self.platform.request("spiflash4x"),
            dummy=6, # see datasheet for dummy cycles
            div=2,   # multiple of 2
            with_bitbang=True,
            endianness=self.cpu.endianness,
            addr32bit=True)
        self.spiflash.add_clk_primitive(self.platform.device)
        self.add_memory_region("spiflash", self.mem_map["spiflash"], self.flash_size, type="io")
        self.add_wb_slave(self.mem_map["spiflash"], self.spiflash.bus, size=self.flash_size)
        self.add_csr("spiflash")
        if self.full_board:
            if self.fast_sd:
                self.submodules.sdmmc = SDCard(self.platform, "sdmmc")
                self.add_wb_master(self.sdmmc.master_bus)
                self.add_memory_region("sdmmc", self.mem_map["sdmmc"], self.sdmmc.get_size(), type="io")
                self.add_wb_slave(self.mem_map["sdmmc"], self.sdmmc.slave_bus, size=self.sdmmc.get_size())
                self.sdmmc_cmd_irq = self.sdmmc.cmd_irq
                self.sdmmc_dat_irq = self.sdmmc.dat_irq
                self.add_interrupt("sdmmc_cmd_irq")
                self.add_interrupt("sdmmc_dat_irq")
            else:
                # SPI0: sd-card
                self.submodules.spi0 = SPIMaster(self.platform, name="sdspi", busmaster=False)
                if hasattr(self.spi0, "master_bus"):
                    self.add_wb_master(self.spi0.master_bus)
                self.add_memory_region("spi0", self.mem_map["spi0"], self.spi0.get_size(), type="io")
                self.add_wb_slave(self.mem_map["spi0"], self.spi0.slave_bus, size=self.spi0.get_size())
                self.add_csr("spi0")
                self.add_interrupt("spi0")
            sd_reset = self.platform.request("sd_reset")
            sd_cd    = self.platform.request("sd_cd")
            self.comb += sd_reset.eq(0)
            # SPI1: waveshare35a
            self.submodules.spi1 = SPIMaster(self.platform, name="ws35a_spi", cs_width=2, busmaster=False)
            if hasattr(self.spi1, "master_bus"):
                self.add_wb_master((self.spi1.master_bus))
            self.add_memory_region("spi1", self.mem_map["spi1"], self.spi1.get_size(), type="io")
            self.add_wb_slave(self.mem_map["spi1"], self.spi1.slave_bus, size=self.spi1.get_size())
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
            # gpio1: touchscreen pendown, sd-card-detect
            gpio1_signals = Cat(ws35a_pendown, sd_cd)
            self.submodules.gpio1 = GPIOIn(gpio1_signals)
            self.add_csr("gpio1")
            # timer1
            self.submodules.timer1 = Timer()
            self.add_csr("timer1")
            self.add_interrupt("timer1")
            # AES
            self.submodules.aes = AES(self.platform)
            self.add_memory_region("aes", self.mem_map["aes"], self.aes.get_size(), type="io")
            self.add_wb_slave(self.mem_map["aes"], self.aes.bus, size=self.aes.get_size())
            # SHA1
            self.submodules.sha1 = SHA1(self.platform)
            self.add_memory_region("sha1", self.mem_map["sha1"], self.sha1.get_size(), type="io")
            self.add_wb_slave(self.mem_map["sha1"], self.sha1.bus, size=self.sha1.get_size())
            # memirq channels
            # channel 0
            self.submodules.to_sel4_master0 = MemIrq()
            self.add_csr("to_sel4_master0")
            self.add_interrupt("to_sel4_master0")
            self.submodules.to_sel4_slave0 = MemIrq()
            self.add_csr("to_sel4_slave0")
            self.add_interrupt("to_sel4_slave0")
            self.submodules.to_linux_master0 = MemIrq()
            self.add_csr("to_linux_master0")
            self.add_interrupt("to_linux_master0")
            self.submodules.to_linux_slave0 = MemIrq()
            self.add_csr("to_linux_slave0")
            self.add_interrupt("to_linux_slave0")
            # channel 1
            self.submodules.to_sel4_master1 = MemIrq()
            self.add_csr("to_sel4_master1")
            self.add_interrupt("to_sel4_master1")
            self.submodules.to_sel4_slave1 = MemIrq()
            self.add_csr("to_sel4_slave1")
            self.add_interrupt("to_sel4_slave1")
            self.submodules.to_linux_master1 = MemIrq()
            self.add_csr("to_linux_master1")
            self.add_interrupt("to_linux_master1")
            self.submodules.to_linux_slave1 = MemIrq()
            self.add_csr("to_linux_slave1")
            self.add_interrupt("to_linux_slave1")
            # dma test
            self.submodules.dmatest = DMATest()
            self.add_wb_master(self.dmatest.master_bus)
            self.add_csr("dmatest")
        self.dts = None


    def init_dts_object(self):
        if self.dts:
            return
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
                #4: "heartbeat",
            }
            d.add_gpio_leds("gpio0", nleds=5, triggers=led_triggers)
            d.add_gpio_restart(reset_gpio=("gpio0", 5, 0))
            d.add_litex_gpio("gpio1", direction="in", ngpio=2)
            d.add_litex_timer("timer1")
            if self.fast_sd:
                d.add_opencores_sdc("sdmmc")
            else:
                spidevs = d.get_spi_mmc(0, "mmc", cd_gpio=("gpio1", 1, 1))
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
            d.add_zsipos_sel4_channel(0)
            d.add_zsipos_sel4_channel(1)
            d.add_zsipos_dmatest("dmatest")
        self.dts = d


    def get_dts(self):
        self.init_dts_object()
        s = self.cpu.build_dts(devices=self.dts.get_devices())
        return s


    def get_csr_offsets(self):
        self.init_dts_object()
        s = self.dts.get_csr_offsets()
        return s


    def write_dts(self, dts_file):
        with open(dts_file, "w") as f:
            f.write(self.get_dts())


    def write_csr_offsets(self, offset_file):
        with open(offset_file, "w") as f:
            f.write(self.get_csr_offsets())


    def set_bios_ip(self, local_ip, remote_ip):
        local_ip = local_ip.split(".")
        remote_ip = remote_ip.split(".")

        self.add_constant("LOCALIP1", int(local_ip[0]))
        self.add_constant("LOCALIP2", int(local_ip[1]))
        self.add_constant("LOCALIP3", int(local_ip[2]))
        self.add_constant("LOCALIP4", int(local_ip[3]))

        self.add_constant("REMOTEIP1", int(remote_ip[0]))
        self.add_constant("REMOTEIP2", int(remote_ip[1]))
        self.add_constant("REMOTEIP3", int(remote_ip[2]))
        self.add_constant("REMOTEIP4", int(remote_ip[3]))


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
    if args.csr_offset_file:
        soc.write_csr_offsets(args.csr_offset_file)
    if args.load:
        load_bistream(builder, FLASH_BITSTREAM_IMAGE)
    if args.flash or args.flashrom:
        if not args.flashrom:
            del FLASH_MAP[FLASH_BOOTROM_OFFSET]
        load_flash(builder, FLASH_MAP)
    if args.buildrom:
        build_flash(builder, FLASH_MAP)

if __name__ == "__main__":
    main()
