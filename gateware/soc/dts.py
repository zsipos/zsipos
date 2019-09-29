import json
from litex.soc.integration import cpu_interface

class DTSHelper():

    def __init__(self, soc, indent=2):
        csr_regions = soc.get_csr_regions()
        memory_regions = soc.get_memory_regions()
        constants = soc.get_constants()
        self.json = json.loads(cpu_interface.get_csr_json(csr_regions, constants, memory_regions))
        self.json.update({"csr_sizes": {}})
        for name, base in self.json["csr_bases"].items():
            size = 0
            for reg, vals in self.json["csr_registers"].items():
                if reg.startswith(name+"_"):
                    addr = vals["addr"]
                    if addr > size:
                        size = addr
            size += self.json["constants"]["config_csr_alignment"] // 8 - base
            self.json["csr_sizes"].update({name: size})
        self.dts = ""
        self.indent = indent
        self.irqlabel = "<&L1>"

    def get_sys_clk_freq(self):
        return self.json["constants"]["config_clock_frequency"]

    def get_cpu_variant(self):
        return self.json["constants"]["config_cpu_variant"]

    def get_sdram_size(self):
        return self.json["memories"]["main_ram"]["size"]

    def get_devices(self):
        return self.dts

    def tabs(self, extra):
        return "\t" * (self.indent+extra)

    def _base(self, name):
        return hex(self.json["csr_bases"][name])

    def _size(self, name):
        return hex(self.json["csr_sizes"][name])

    def _irq(self, name, suffix="_interrupt"):
        return str(self.json["constants"][name+suffix]+1)

    def _irqparent(self):
        return "interrupt-parent = " + self.irqlabel

    def _const(self, name):
        return str(self.json["constants"][name])

    def _memreg(self, name):
        m = self.json["memories"][name]
        return hex(m["base"]) + " " + hex(m["size"])

    def add_litex_uart(self, index, uart):
        if index:
            uart += str(index)
        s = ""
        s += self.tabs(0) + "uart" + str(index) + ": uart@" + self._base(uart)[2:] + " {\n"
        s += self.tabs(1) + 'compatible = "litex,uart0";\n'
        s += self.tabs(1) + self._irqparent() + ";\n"
        s += self.tabs(1) + "interrupts = <" + self._irq(uart) + ">;\n"
        s += self.tabs(1) + "reg = <" + self._base(uart) + " " + self._size(uart) + ">;\n"
        s += self.tabs(0) + "};\n"
        self.dts += s

    def add_litex_eth(self, index, phy, mac):
        if index:
            phy += str(index)
            mac += str(index)
        s = ""
        s += self.tabs(0) + "eth" + str(index) + ": eth@" + self._base(mac)[2:] + " {\n"
        s += self.tabs(1) + 'compatible = "litex,liteeth";\n'
        s += self.tabs(1) + self._irqparent() + ";\n"
        s += self.tabs(1) + "interrupts = <" + self._irq(mac) + ">;\n"
        s += self.tabs(1) + "tx-fifo-depth = <" + self._const(mac + "_tx_slots") + ">;\n"
        s += self.tabs(1) + "rx-fifo-depth = <" + self._const(mac + "_rx_slots") + ">;\n"
        s += self.tabs(1) + "reg = \t<" + self._base(mac) + " " + self._size(mac) + "\n"
        s += self.tabs(2) + " " + self._base(phy) + " " + self._size(phy) + "\n"
        s += self.tabs(2) + " " + self._memreg(mac) + ">;\n"
        s += self.tabs(0) + "};\n"
        self.dts += s

def dtshelper_args(parser):
    parser.add_argument("--dts-file", default=None, help="device tree file")
