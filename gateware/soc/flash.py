import os
from litex.build.openocd import OpenOCD

class Programmer():
    def __init__(self, soc):
        self.bitstream_file = os.path.join("build" + "_" + os.environ["BOARD"], "gateware", "top.bit")

    def load(self):
        pass

    def flash(self, regions):
        pass

class XilinxProgrammer(Programmer):
    def __init__(self, soc):
        Programmer.__init__(self, soc)
        openocddir = os.path.join(os.environ["RISCV"], "share", "openocd")
        cfg = os.path.join(openocddir, "openocd_xilinx.cfg")
        flash_proxy = os.path.join("bscan_spi_bitstreams", "bscan_spi_"+soc.platform.device.split("-", 1)[0]+".bit")
        self.prog = OpenOCD(cfg, flash_proxy_basename=flash_proxy)
        self.prog.set_flash_proxy_dir(openocddir)

    def load(self):
        self.prog.load_bitstream(self.bitstream_file)

    def flash(self, regions):
        regions.update({self.bitstream_file: "0x0"})
        for filename, base in regions.items():
            base = int(base, 16)
            print("Flashing {} at 0x{:08x}".format(filename, base))
            self.prog.flash(base, filename)

def get_programmer(soc):
    return XilinxProgrammer(soc)

def load_bistream(soc):
    prog = get_programmer(soc)
    prog.load()

def load_flash(soc, regions={}):
    prog = get_programmer(soc)
    prog.flash(regions)

def flashhelper_args(parser):
    parser.add_argument("--load", action="store_true", help="load bistream")
    parser.add_argument("--flash", action="store_true", help="load flash")


