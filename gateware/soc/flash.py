import os
from litex.build.openocd import OpenOCD

class Programmer():
    def __init__(self, soc):
        self.bitstream_file = os.path.join("build" + "_" + os.environ["BOARD"], "gateware", "top.bit")

    def load_bitstream(self):
        pass

class XilinxProgrammer(Programmer):
    def __init__(self, soc):
        Programmer.__init__(self, soc)
        self.openocddir = os.path.join(os.environ["RISCV"], "share", "openocd")
        self.prog = OpenOCD(os.path.join(self.openocddir, "openocd_xilinx.cfg"))

    def load_bitstream(self):
        self.prog.load_bitstream(self.bitstream_file)

def get_programmer(soc):
    return XilinxProgrammer(soc)

def load_bistream(soc):
    prog = get_programmer(soc)
    prog.load_bitstream()

def load_flash(soc):
    pass

def flashhelper_args(parser):
    parser.add_argument("--load", action="store_true", help="load bistream")
    parser.add_argument("--flash", action="store_true", help="load flash")


