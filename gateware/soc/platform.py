from litex.build.generic_platform import *
from litex.build.xilinx import XilinxPlatform, VivadoProgrammer

# IOs ----------------------------------------------------------------------------------------------

_io = [
    #("user_led", 0, Pins("H5"), IOStandard("LVCMOS33")),
    #("user_sw", 0, Pins("A8"), IOStandard("LVCMOS33")),
    #("user_btn", 0, Pins("D9"), IOStandard("LVCMOS33")),

    ("clk100", 0, Pins("F4"), IOStandard("SSTL15")),

    ("cpu_reset", 0, Pins("F5"), IOStandard("LVCMOS15")),

    ("serial", 0,
        Subsignal("tx", Pins("B8")),
        Subsignal("rx", Pins("A8")),
        IOStandard("LVCMOS33")
    ),

    ("spiflash4x", 0,
        Subsignal("cs_n", Pins("L13")),
        #Subsignal("clk", Pins("E9")),
        Subsignal("dq", Pins("K17", "K18", "L14", "M14")),
        IOStandard("LVCMOS33")
    ),
    ("spiflash", 0,
        Subsignal("cs_n", Pins("L13")),
        #Subsignal("clk", Pins("E9")),
        Subsignal("mosi", Pins("K17")),
        Subsignal("miso", Pins("K18")),
        Subsignal("wp", Pins("L14")),
        Subsignal("hold", Pins("M14")),
        IOStandard("LVCMOS33"),
    ),

    ("ddram", 0,
        Subsignal("a", Pins(
            "D3 B2 G1 D4 E1 D2 F1 D5",
            "C1 B3 E3 A1 E2 B4 C2 H1"),
            IOStandard("SSTL15")),
        Subsignal("ba", Pins("J4 F3 G2"), IOStandard("SSTL15")),
        Subsignal("ras_n", Pins("J2"), IOStandard("SSTL15")),
        Subsignal("cas_n", Pins("H6"), IOStandard("SSTL15")),
        Subsignal("we_n", Pins("G4"), IOStandard("SSTL15")),
        Subsignal("cs_n", Pins("H5"), IOStandard("SSTL15")),
        Subsignal("dm", Pins("E6"), IOStandard("SSTL15")),
        Subsignal("dq", Pins(
            "C5 B7 B6 C6 C7 D8 E5 E7"),
            IOStandard("SSTL15"),
            Misc("IN_TERM=UNTUNED_SPLIT_40")),
        Subsignal("dqs_p", Pins("A6"), IOStandard("DIFF_SSTL15")),
        Subsignal("dqs_n", Pins("A5"), IOStandard("DIFF_SSTL15")),
        Subsignal("clk_p", Pins("A4"), IOStandard("DIFF_SSTL15")),
        Subsignal("clk_n", Pins("A3"), IOStandard("DIFF_SSTL15")),
        Subsignal("cke", Pins("H2"), IOStandard("SSTL15")),
        Subsignal("odt", Pins("G6"), IOStandard("SSTL15")),
        Subsignal("reset_n", Pins("B1"), IOStandard("LVCMOS15")),
        Misc("SLEW=FAST"),
    ),

    ("eth_pwdn", 0, Pins("T18"), IOStandard("LVCMOS33")),
    ("eth_clocks", 0,
        Subsignal("tx", Pins("T14")),
        Subsignal("rx", Pins("N15")),
        IOStandard("LVCMOS33"),
    ),
    ("eth", 0,
        Subsignal("rst_n", Pins("U14")),
        Subsignal("mdio", Pins("V14")),
        Subsignal("mdc", Pins("T13")),
        Subsignal("rx_dv", Pins("V10")),
        Subsignal("rx_er", Pins("V11")),
        Subsignal("rx_data", Pins("U12 V12 U13 T15")),
        Subsignal("tx_en", Pins("R15")),
        Subsignal("tx_data", Pins("R16 U18 R18 R17")),
        Subsignal("col", Pins("T9")),
        Subsignal("crs", Pins("U11")),
        IOStandard("LVCMOS33"),
    ),

    ("eth_pwdn", 1, Pins("D10"), IOStandard("LVCMOS33")),
    ("eth_clocks", 1,
        Subsignal("tx", Pins("P17")),
        Subsignal("rx", Pins("P15")),
        IOStandard("LVCMOS33"),
    ),
    ("eth", 1,
        #no rst_n, hardwired to eth.rst_n
        Subsignal("mdio", Pins("P18")),
        Subsignal("mdc", Pins("N14")),
        Subsignal("rx_dv", Pins("R11")),
        Subsignal("rx_er", Pins("U16")),
        Subsignal("rx_data", Pins("V17 T16 U17 N17")),
        Subsignal("tx_en", Pins("N16")),
        Subsignal("tx_data", Pins("M13 M16 M17 L16")),
        Subsignal("col", Pins("P14")),
        Subsignal("crs", Pins("V16")),
        IOStandard("LVCMOS33"),
     ),
]

_connectors = [
]

# Platform -----------------------------------------------------------------------------------------

class Platform(XilinxPlatform):
    default_clk_name = "clk100"
    default_clk_period = 1e9/100e6

    def __init__(self):
        XilinxPlatform.__init__(self, "xc7a100tcsg324-2", _io, _connectors, toolchain="vivado")
        self.toolchain.bitstream_commands = \
            ["set_property BITSTREAM.CONFIG.SPI_BUSWIDTH 4 [current_design]"]
        self.toolchain.additional_commands = \
            ["write_cfgmem -force -format bin -interface spix4 -size 16 "
             "-loadbit \"up 0x0 {build_name}.bit\" -file {build_name}.bin"]
        #self.add_platform_command("set_property INTERNAL_VREF 0.675 [get_iobanks 34]")

    def create_programmer(self):
        return VivadoProgrammer(flash_part="n25q128-3.3v-spi-x1_x2_x4")
