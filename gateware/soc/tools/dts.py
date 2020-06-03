import json
from litex.soc.integration import cpu_interface

class DTSHelper():

    def __init__(self, soc, indent=2):
        if hasattr(soc, "csr_regions"):
            csr_regions    = soc.csr_regions
            memory_regions = soc.mem_regions
            constants      = soc.constants
        else:
            csr_regions    = soc.get_csr_regions()
            memory_regions = soc.get_memory_regions()
            constants      = soc.get_constants()
        self.json = json.loads(cpu_interface.get_csr_json(csr_regions, constants, memory_regions))
        self.json.update({"csr_sizes": {}})
        for name, base in self.json["csr_bases"].items():
            size = 0
            for reg, vals in self.json["csr_registers"].items():
                # find largest addr for this name
                if reg.startswith(name+"_"):
                    addr = vals["addr"]
                    if addr > size:
                        size = addr
            size += vals["size"] * self.json["constants"]["config_csr_alignment"] // 8 - base
            self.json["csr_sizes"].update({name: size})
        self.dts = ""
        self.indent = indent
        self.irqlabel = "L1"
        self.add_zsipos_clock()

    def print_csr_offsets(self, names=None):
        print(self.get_csr_offsets(names))

    def get_csr_offsets(self, names=None):
        s = ""
        if names is None:
            names = [ name for name, _ in self.json["csr_bases"].items() ]
        align = self.json["constants"]["config_csr_alignment"] // 8
        s += "#define LITEX_CSR_OFFSET(x)    ((x)*" + str(align) + ")\n\n"
        for name in names:
            base = self.json["csr_bases"][name]
            regs = []
            maxlen_name = 0
            maxlen_offset = 0
            for reg, vals in self.json["csr_registers"].items():
                if reg.startswith(name+"_"):
                    offset = (vals["addr"] - base) // align
                    if offset < 0:
                        continue
                    offset = str(offset)
                    maxlen_offset = max(maxlen_offset, len(offset))
                    maxlen_name = max(maxlen_name, len(reg))
                    regs.append((reg, offset, vals["size"]))
            regs.sort(key=lambda i: int(i[1]))
            for reg, offset, width in regs:
                s += "#define LITEX_" + reg.upper() + "_REG"
                s += " "*(4+maxlen_name-len(reg))
                s += "LITEX_CSR_OFFSET(" + offset + ")"
                s += " "*(1+maxlen_offset-len(offset)) + "// u" + str(width*8) + "\n"
            s += "\n"
        return s

    def get_sys_clk_freq(self):
        return self.json["constants"]["config_clock_frequency"]

    def get_cpu_variant(self):
        return self.json["constants"]["config_cpu_variant"]

    def get_sdram_size(self):
        return self.json["memories"]["main_ram"]["size"]

    def get_devices(self):
        return self.dts

    def get_spi_mmc(self, index, mmc = "mmc", cd_gpio=None):
        s = ""
        s += self.tabs(1) + mmc + "@" + str(index) + " {\n"
        s += self.tabs(2) + 'compatible = "mmc-spi-slot";\n'
        s += self.tabs(2) + "reg = <" + str(index) + ">;\n"
        s += self.tabs(2) + "voltage-ranges = <3300 3300>;\n"
        s += self.tabs(2) + "spi-max-frequency = <25000000>;\n"
        if cd_gpio:
            s += self.tabs(2) + "gpios = <&" + self._gpio_pin(cd_gpio) + ">;\n"
        if self.json["constants"].get(mmc+"_interrupt"):
            s += self.tabs(2) + self._irqparent() + ";\n"
            s += self.tabs(2) + "interrupts = <" + self._irq(mmc) + ">;\n"
        s += self.tabs(1) + "};\n"
        return s

    def get_spi_waveshare35a(self, index, ws, reset_gpio, dc_gpio, pendown_gpio, rotation=90):
        s = ""
        s += self.tabs(1) + ws + "_display@" + str(index) + " {\n"
        s += self.tabs(2) + 'compatible = "ilitek,ili9486";\n'
        s += self.tabs(2) + "reg = <" + str(index) + ">;\n"
        s += self.tabs(2) + "spi-max-frequency = <16000000>;\n"
        s += self.tabs(2) + "txbuflen = <32768>;\n"
        s += self.tabs(2) + "rotate = <" + str(rotation) + ">;\n"
        s += self.tabs(2) + "bgr = <0>;\n"
        s += self.tabs(2) + "fps = <30>;\n"
        s += self.tabs(2) + "buswidth = <8>;\n"
        s += self.tabs(2) + "regwidth = <16>;\n"
        s += self.tabs(2) + "reset-gpios = <&" + self._gpio_pin(reset_gpio) + ">;\n"
        s += self.tabs(2) + "dc-gpios = <&" + self._gpio_pin(dc_gpio) + ">;\n"
        s += self.tabs(2) + "debug = <0>;\n"
        s += self.tabs(2) + "init = <0x10000b0 0x00\n"
        s += self.tabs(3) + "0x1000011\n"
        s += self.tabs(3) + "0x20000ff\n"
        s += self.tabs(3) + "0x100003a 0x55\n"
        s += self.tabs(3) + "0x1000036 0x28\n"
        s += self.tabs(3) + "0x10000c2 0x44\n"
        s += self.tabs(3) + "0x10000c5 0x00 0x00 0x00 0x00\n"
        s += self.tabs(3) + "0x10000e0 0x0f 0x1f 0x1c 0x0c 0x0f 0x08 0x48 0x98 0x37 0x0a 0x13 0x04 0x11 0x0d 0x00\n"
        s += self.tabs(3) + "0x10000e1 0x0f 0x32 0x2e 0x0b 0x0d 0x05 0x47 0x75 0x37 0x06 0x10 0x03 0x24 0x20 0x00\n"
        s += self.tabs(3) + "0x10000e2 0x0f 0x32 0x2e 0x0b 0x0d 0x05 0x47 0x75 0x37 0x06 0x10 0x03 0x24 0x20 0x00\n"
        s += self.tabs(3) + "0x1000036 0x28\n"
        s += self.tabs(3) + "0x1000011\n"
        s += self.tabs(3) + "0x1000029>;\n"
        s += self.tabs(1) + "};\n"
        s += self.tabs(1) + ws + "_touch@" + str(index+1) + " {\n"
        s += self.tabs(2) + 'compatible = "ti,ads7846";\n'
        s += self.tabs(2) + "reg = <" + str(index+1) + ">;\n"
        s += self.tabs(2) + "spi-max-frequency = <2000000>;\n"
        s += self.tabs(2) + self._irqparent() + ";\n"
        s += self.tabs(2) + "interrupts = <" + self._irq(ws) + ">;\n"
        s += self.tabs(2) + "pendown-gpio = <&" + self._gpio_pin(pendown_gpio) + ">;\n"
        s += self.tabs(2) + "ti,keep-vref-on = <1>;\n"
        s += self.tabs(2) + "ti,swap-xy = <1>;\n"
        s += self.tabs(2) + "ti,x-plate-ohms = /bits/ 16 <60>;\n"
        s += self.tabs(2) + "ti,pressure-max = /bits/ 16 <255>;\n"
        s += self.tabs(2) + "ti,x-min = /bits/ 16 <200>;\n"
        s += self.tabs(2) + "ti,x-max = /bits/ 16 <3900>;\n"
        s += self.tabs(2) + "ti,y-min = /bits/ 16 <200>;\n"
        s += self.tabs(2) + "ti,y-max = /bits/ 16 <3900>;\n"
        s += self.tabs(2) + "wakeup-source;\n"
        s += self.tabs(1) + "};\n"
        return s

    def tabs(self, extra):
        return "\t" * (self.indent+extra)

    def _base(self, name):
        return hex(self.json["csr_bases"][name])

    def _size(self, name):
        return hex(self.json["csr_sizes"][name])

    def _irq(self, name, suffix="_interrupt"):
        return str(self.json["constants"][name+suffix]+1)

    def _irqparent(self):
        return "interrupt-parent = <&" + self.irqlabel + ">"

    def _const(self, name):
        return str(self.json["constants"][name])

    def _memreg(self, name):
        m = self.json["memories"][name]
        return hex(m["base"]) + " " + hex(m["size"])

    def _membase(self, name):
        m = self.json["memories"][name]
        return hex(m["base"])

    def _gpio_pin(self, gpio):
        return str(gpio[0]) + " " + str(gpio[1]) + " " + str(gpio[2])

    def add_zsipos_clock(self):
        s = ""
        s += self.tabs(0) + "zsiposclock: zsiposclock {\n"
        s += self.tabs(1) + "#clock-cells = <0>;\n"
        s += self.tabs(1) + 'compatible = "fixed-clock";\n'
        s += self.tabs(1) + 'clock-output-names = "zsiposclock";\n'
        s += self.tabs(1) + "clock-frequency = <" + str(self.get_sys_clk_freq()) + ">;\n"
        s += self.tabs(0) + "};\n"
        self.dts += s

    def add_gpio_leds(self, gpio, nleds, triggers={}):
        s = ""
        s += self.tabs(0) + "gpio_leds" + " {\n"
        s += self.tabs(1) + 'compatible = "gpio-leds";\n'
        for i in range(nleds):
            trigger = triggers.get(i)
            if trigger:
                s += self.tabs(1) + "led" + str(i) + " {\n"
                s += self.tabs(2) + 'label = "' + trigger + '";\n'
                s += self.tabs(2) + "gpios = <&" + self._gpio_pin((gpio, i, 0)) + ">;\n"
                s += self.tabs(2) + 'linux,default-trigger = "' + trigger + '";\n'
                s += self.tabs(1) + "};\n"
        s += self.tabs(0) + "};\n"
        self.dts += s

    def add_gpio_restart(self, reset_gpio):
        s = ""
        s += self.tabs(0) + "gpio_restart" + " {\n"
        s += self.tabs(1) + 'compatible = "gpio-restart";\n'
        s += self.tabs(2) + "gpios = <&" + self._gpio_pin(reset_gpio) + ">;\n"
        s += self.tabs(2) + "priority = <255>;\n"
        s += self.tabs(0) + "};\n"
        self.dts += s

    def add_litex_uart(self, uart):
        s = ""
        s += self.tabs(0) + uart + ": uart@" + self._base(uart)[2:] + " {\n"
        s += self.tabs(1) + 'compatible = "litex,uart0";\n'
        s += self.tabs(1) + self._irqparent() + ";\n"
        s += self.tabs(1) + "interrupts = <" + self._irq(uart) + ">;\n"
        s += self.tabs(1) + "reg = <" + self._base(uart) + " " + self._size(uart) + ">;\n"
        s += self.tabs(0) + "};\n"
        self.dts += s

    def add_litex_eth(self, phy, mac):
        s = ""
        s += self.tabs(0) + mac + ": " + mac + "@" + self._base(mac)[2:] + " {\n"
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

    def add_litex_gpio(self, gpio, direction, ngpio):
        assert direction in ["in", "out"]
        s = ""
        s += self.tabs(0) + gpio + ": gpio@" + self._base(gpio)[2:] + " {\n"
        s += self.tabs(1) + "#gpio-cells = <2>;\n"
        s += self.tabs(1) + 'compatible = "litex,gpio";\n'
        s += self.tabs(1) + "gpio-controller;\n"
        s += self.tabs(1) + 'litex,direction = "' + direction + '";\n'
        s += self.tabs(1) + "litex,ngpio = <" + str(ngpio) + ">;\n"
        s += self.tabs(1) + "reg = <" + self._base(gpio) + " " + self._size(gpio) + ">;\n"
        s += self.tabs(0) + "};\n"
        self.dts += s

    def add_litex_timer(self, timer):
        s = ""
        s += self.tabs(0) + timer + ": " + timer + "@" + self._base(timer)[2:] + " {\n"
        s += self.tabs(1) + 'compatible = "litex,timer";\n'
        s += self.tabs(1) + self._irqparent() + ";\n"
        s += self.tabs(1) + "interrupts = <" + self._irq(timer) + ">;\n"
        s += self.tabs(1) + "reg = <" + self._base(timer) + " " + self._size(timer) + ">;\n"
        s += self.tabs(0) + "};\n"
        self.dts += s

    def add_opencores_sdc(self, sdmmc):
        s = ""
        s += self.tabs(0) + sdmmc + ": ocsdc@" + self._membase(sdmmc)[2:] + " {\n"
        s += self.tabs(1) + 'compatible = "opencores,ocsdc";\n'
        s += self.tabs(1) + 'clocks = <&zsiposclock>;\n'
        s += self.tabs(1) + self._irqparent() + ";\n"
        s += self.tabs(1) + "interrupts = <" + self._irq(sdmmc+"_cmd_irq") + " " + self._irq(sdmmc+"_dat_irq") + ">;\n"
        s += self.tabs(1) + "reg = <" + self._memreg(sdmmc) + ">;\n"
        s += self.tabs(0) + "};\n"
        self.dts += s

    def add_zsipos_spi(self, spi, devices=None):
        s = ""
        s += self.tabs(0) + spi + ": spi@" + self._membase(spi)[2:] + " {\n"
        s += self.tabs(1) + "#address-cells = <1>;\n"
        s += self.tabs(1) + "#size-cells = <0>;\n"
        s += self.tabs(1) + 'compatible = "zsipos,spi";\n'
        s += self.tabs(1) + 'clocks = <&zsiposclock>;\n'
        s += self.tabs(1) + self._irqparent() + ";\n"
        s += self.tabs(1) + "interrupts = <" + self._irq(spi) + ">;\n"
        s += self.tabs(1) + "reg = <" + self._memreg(spi) + ">;\n"
        if devices:
            s += devices
        s += self.tabs(0) + "};\n"
        self.dts += s

    def add_zsipos_spim(self, spim, devices=None):
        s = ""
        s += self.tabs(0) + spim + ": spi@" + self._base(spim)[2:] + " {\n"
        s += self.tabs(1) + "#address-cells = <1>;\n"
        s += self.tabs(1) + "#size-cells = <0>;\n"
        s += self.tabs(1) + 'compatible = "zsipos,spi-m";\n'
        s += self.tabs(1) + "cs-width = <" + self._const(spim + "_cs_width") + ">;\n"
        s += self.tabs(1) + "mem-size = <" + self._const(spim + "_mem_size") + ">;\n"
        s += self.tabs(1) + 'clocks = <&zsiposclock>;\n'
        s += self.tabs(1) + self._irqparent() + ";\n"
        s += self.tabs(1) + "interrupts = <" + self._irq(spim) + ">;\n"
        if self.json["constants"].get(spim + "_can_dma"):
            s += self.tabs(1) + "can-dma = <1>;\n"
        s += self.tabs(1) + "reg = \t<" + self._base(spim) + " " + self._size(spim) + "\n"
        s += self.tabs(2) + " " + self._memreg(spim) + ">;\n"
        if devices:
            s += devices
        s += self.tabs(0) + "};\n"
        self.dts += s

    def add_zsipos_aes(self, aes):
        s = ""
        s += self.tabs(0) + aes + ": aes@" + self._membase(aes)[2:] + " {\n"
        s += self.tabs(1) + 'compatible = "zsipos,aes";\n'
        s += self.tabs(1) + "reg = <" + self._memreg(aes) + ">;\n"
        s += self.tabs(0) + "};\n"
        self.dts += s

    def add_zsipos_sha1(self, sha1):
        s = ""
        s += self.tabs(0) + sha1 + ": sha1@" + self._membase(sha1)[2:] + " {\n"
        s += self.tabs(1) + 'compatible = "zsipos,sha1";\n'
        s += self.tabs(1) + "reg = <" + self._memreg(sha1) + ">;\n"
        s += self.tabs(0) + "};\n"
        self.dts += s

    def add_zsipos_sel4_channel(self, nr):

        s = ""

        # linux --> sel4
        master = "to_sel4_master" + str(nr)
        slave  = "to_sel4_slave"  + str(nr)
        size = 4096
        base = self.json["memories"]["sram"]["base"] + size * nr * 2

        # linux -> sel4 master
        s += self.tabs(0) + master + ": to_sel4_master@" + str(nr) + " {\n"
        s += self.tabs(1) + 'compatible = "zsipos,to_sel4_master";\n'
        s += self.tabs(1) + 'channel = <' + str(nr) + ">;\n"
        s += self.tabs(1) + self._irqparent() + ";\n"
        s += self.tabs(1) + "interrupts = <" + self._irq(slave) + ">;\n"
        s += self.tabs(1) + "reg =  <" + self._base(master) + " " + self._size(master) + "\n"
        s += self.tabs(2) + self._base(slave) + " " + self._size(slave) + "\n"
        s += self.tabs(2) + hex(base) + " " + hex(size) + ">;\n"
        s += self.tabs(0) + "};\n"
        # linux -> sel4 slave
        s += self.tabs(0) + slave + ": to_sel4_slave@" + str(nr) + " {\n"
        s += self.tabs(1) + 'compatible = "zsipos,to_sel4_slave";\n'
        s += self.tabs(1) + 'channel = <' + str(nr) + ">;\n"
        s += self.tabs(1) + self._irqparent() + ";\n"
        s += self.tabs(1) + "interrupts = <" + self._irq(master) + ">;\n"
        s += self.tabs(1) + "reg =  <" + self._base(master) + " " + self._size(master) + "\n"
        s += self.tabs(2) + self._base(slave) + " " + self._size(slave) + "\n"
        s += self.tabs(2) + hex(base) + " " + hex(size) + ">;\n"
        s += self.tabs(0) + "};\n"

        # sel4 --> linux
        master = "to_linux_master" + str(nr)
        slave  = "to_linux_slave"  + str(nr)
        base += size

        # sel4 -> linux master
        s += self.tabs(0) + master + ": to_linux_master@" + str(nr) + " {\n"
        s += self.tabs(1) + 'compatible = "zsipos,to_linux_master";\n'
        s += self.tabs(1) + 'channel = <' + str(nr) + ">;\n"
        s += self.tabs(1) + self._irqparent() + ";\n"
        s += self.tabs(1) + "interrupts = <" + self._irq(slave) + ">;\n"
        s += self.tabs(1) + "reg =  <" + self._base(master) + " " + self._size(master) + "\n"
        s += self.tabs(2) + self._base(slave) + " " + self._size(slave) + "\n"
        s += self.tabs(2) + hex(base) + " " + hex(size) + ">;\n"
        s += self.tabs(0) + "};\n"
        # sel4 -> linux slave
        s += self.tabs(0) + slave + ": to_linux_slave@" + str(nr) + " {\n"
        s += self.tabs(1) + 'compatible = "zsipos,to_linux_slave";\n'
        s += self.tabs(1) + 'channel = <' + str(nr) + ">;\n"
        s += self.tabs(1) + self._irqparent() + ";\n"
        s += self.tabs(1) + "interrupts = <" + self._irq(master) + ">;\n"
        s += self.tabs(1) + "reg =  <" + self._base(master) + " " + self._size(master) + "\n"
        s += self.tabs(2) + self._base(slave) + " " + self._size(slave) + "\n"
        s += self.tabs(2) + hex(base) + " " + hex(size) + ">;\n"
        s += self.tabs(0) + "};\n"

        self.dts += s

    def add_zsipos_dmatest(self, dma):
        s = ""
        s += self.tabs(0) + dma + ": dmatest@" + self._base(dma)[2:] + " {\n"
        s += self.tabs(1) + 'compatible = "zsipos,dmatest";\n'
        s += self.tabs(1) + "reg = <" + self._base(dma) + " " + self._size(dma) + ">;\n"
        s += self.tabs(0) + "};\n"
        self.dts += s


def dtshelper_args(parser):
    parser.add_argument("--csr-offset-file", default=None, help="csr offset c-header file")
    parser.add_argument("--dts-file", default=None, help="device tree file")
