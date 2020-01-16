import os
import sys
import zlib
from litex.build.openocd import OpenOCD
from litex.build.xilinx.programmer import _run_vivado

class XilinxOCDProgrammer():
    def __init__(self, soc):
        openocddir = os.path.join(os.environ["ZTC_TOOLS_DIR"], "share", "openocd")
        cfg = os.path.join(openocddir, "openocd_xilinx.cfg")
        device = soc.platform.device.split("-", 1)[0]
        if device == "xc7a35ticsg324":
            device = "xc7a35t"
        flash_proxy = os.path.join("bscan_spi_bitstreams", "bscan_spi_"+device+".bit")
        self.prog = OpenOCD(cfg, flash_proxy_basename=flash_proxy)
        self.prog.set_flash_proxy_dir(openocddir)

    def load(self, bitstream_file):
        self.prog.load_bitstream(bitstream_file)

    def flash(self, regions):
        for _, item in regions.items():
            print("Flashing {} at 0x{:08x}".format(item[0], item[2]))
            self.prog.flash(item[2], item[0])


def load_bistream(builder, bitstream_file):
    programmer = builder.soc.platform.create_programmer()
    programmer.load_bitstream(bitstream_file)

def _flash_file(programmer, flash_size, offset, type, file, mcs_file, device):
    cmds  = 'write_cfgmem -format mcs -interface {iface} -size {flash_size} -load{type} "up {offset} {file}" -file "{mcs_file}" -force'
    cmds = cmds.format(iface="spix4", flash_size=flash_size, type=type, offset=hex(offset), file=file, mcs_file=mcs_file)
    cmds += """
open_hw
connect_hw_server
open_hw_target
create_hw_cfgmem -hw_device [lindex [get_hw_devices] {{{device}}}] -mem_dev  [lindex [get_cfgmem_parts {{{flash_part}}}] 0]
refresh_hw_device [lindex [get_hw_devices] {{{device}}}]
set_property PROGRAM.FILES [list "{data}" ] [ get_property PROGRAM.HW_CFGMEM [lindex [get_hw_devices] {{{device}}} ]]
set_property PROGRAM.UNUSED_PIN_TERMINATION {{pull-none}} [ get_property PROGRAM.HW_CFGMEM [lindex [get_hw_devices] {{{device}}} ]]
set_property PROGRAM.BLANK_CHECK  0 [ get_property PROGRAM.HW_CFGMEM [lindex [get_hw_devices] {{{device}}} ]]
"""
    if offset == 0:
        cmds += """
set_property PROGRAM.ADDRESS_RANGE {{entire_device}} [ get_property PROGRAM.HW_CFGMEM [lindex [get_hw_devices] {{{device}}} ]]
set_property PROGRAM.ERASE 1 [ get_property PROGRAM.HW_CFGMEM [lindex [get_hw_devices] {{{device}}} ]]
"""
    else:
        cmds += """
set_property PROGRAM.ERASE 0 [ get_property PROGRAM.HW_CFGMEM [lindex [get_hw_devices] {{{device}}} ]]
"""
    cmds += """
set_property PROGRAM.CFG_PROGRAM 1 [ get_property PROGRAM.HW_CFGMEM [lindex [get_hw_devices] {{{device}}} ]]
set_property PROGRAM.VERIFY 1 [ get_property PROGRAM.HW_CFGMEM [lindex [get_hw_devices] {{{device}}} ]]

startgroup
if {{![string equal [get_property PROGRAM.HW_CFGMEM_TYPE  [lindex [get_hw_devices] {{{device}}}]] [get_property MEM_TYPE [get_property CFGMEM_PART [get_property PROGRAM.HW_CFGMEM [lindex [get_hw_devices] {{{device}}} ]]]]] }}  {{ create_hw_bitstream -hw_device [lindex [get_hw_devices] {{{device}}}] [get_property PROGRAM.HW_CFGMEM_BITFILE [ lindex [get_hw_devices] {{{device}}}]]; program_hw_devices [lindex [get_hw_devices] {{{device}}}]; }};
program_hw_cfgmem -hw_cfgmem [get_property PROGRAM.HW_CFGMEM [lindex [get_hw_devices] {{{device}}} ]]
endgroup

quit
"""
    cmds = cmds.format(data=mcs_file, flash_part=programmer.flash_part, device=device)
    _run_vivado(programmer.vivado_path, programmer.vivado_ver, cmds)

def load_flash(builder, regions, device=0):
    mcs_file = os.path.join(builder.output_dir, "gateware", "top.mcs")
    flash_size = builder.soc.flash_size // 1024 // 1024
    programmer = builder.soc.platform.create_programmer()
    for offset, item in regions.items():
        bin_file = item[0]
        if item[2]:
            tmp_file = os.path.join(builder.output_dir, "gateware", "tmp.tmp")
            add_len_crc32(bin_file, tmp_file, endianess=builder.soc.cpu.endianness)
            bin_file = tmp_file
        _flash_file(programmer, flash_size, offset, item[1], bin_file, mcs_file, device)

def add_len_crc32(src, dst, endianess="little"):
    len = os.path.getsize(src)
    crc = int(0)
    with open(dst, "wb") as fd:
        fd.write(len.to_bytes(4, byteorder=endianess))
        # dummy for crc
        fd.write(crc.to_bytes(4, byteorder=endianess))
        with open(src, "rb") as fs:
            while True:
                s = fs.read(8192)
                if not s:
                    break
                fd.write(s)
                crc = zlib.crc32(s, crc)
        # write calculated crc
        fd.seek(4)
        fd.write(crc.to_bytes(4, byteorder=endianess))

def flashhelper_args(parser):
    parser.add_argument("--load", action="store_true", help="load bistream")
    parser.add_argument("--flash", action="store_true", help="load flash")
    parser.add_argument("--flashrom", action="store_true", help="load flash and bootrom")
