# SPDX-FileCopyrightText: 2019 Stefan Adams <stefan.adams@vipcomag.de>
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Note: this program assumes that the dts is generated from zsipos chip generator.
# It will not work on a generic devicetree!!!

import os, sys
from pyfdt.pyfdt import *

MEM_BASE = 0x80000000
PAGESIZE = 4096

copy_to_sel4 = ["riscv,plic0", "riscv,clint0"]
move_to_sel4 = ["litex,liteeth"]#, "zsipos,to_sel4_slave", "zsipos,to_linux_master"]
#move_to_sel4 = []


def build_linux_dts(dtb, sel4_size, dst_dir):
    dts_name = os.path.join(dst_dir, "linux.dts")
    fdt = dtb.to_fdt()
    # fix the memory
    mem = fdt.resolve_path("/memory@" + hex(MEM_BASE)[2:])
    mem.name = "memory@" + hex(MEM_BASE+sel4_size)[2:]
    reg = mem[mem.index("reg")]
    reg.words[0] += sel4_size
    reg.words[1] -= sel4_size
    # delete all moved devices
    soc = fdt.resolve_path("/soc")
    to_delete = []
    for i in soc:
        if isinstance(i, FdtNode):
            try:
                compat = i[i.index("compatible")][0]
            except ValueError:
                continue
            if compat in move_to_sel4:
                to_delete.append(i.get_name())
    for i in to_delete:
        soc.remove(i)
    # write dts
    with open(dts_name, "w") as f:
        f.write(fdt.to_dts())


def build_sel4_dts(dtb, sel4_size, dst_dir):
    dts_name = os.path.join(dst_dir, "sel4.dts")
    ovl_name = os.path.join(dst_dir, "overlay-sel4.dts")

    # build sel4 devicetree
    fdt = dtb.to_fdt()
    # fix the memory
    mem = fdt.resolve_path("/memory@" + hex(MEM_BASE)[2:])
    reg = mem[mem.index("reg")]
    reg.words[1] = sel4_size
    # delete chosen
    fdt.get_rootnode().remove("chosen")
    # delete all cpus except 0
    cpus = fdt.resolve_path("/cpus")
    i = 1
    while True:
        try:
            index = cpus.index("cpu@" + str(i))
        except ValueError:
            break
        cpus.pop(index)
        i = i + 1
    # delete all non sel4 devices
    soc = fdt.resolve_path("/soc")
    to_delete = []
    for i in soc:
        if isinstance(i, FdtNode):
            try:
                compat = i[i.index("compatible")][0]
            except ValueError:
                continue
            if not (compat in copy_to_sel4 or compat in move_to_sel4):
                to_delete.append(i.get_name())
    for i in to_delete:
        soc.remove(i)
    # fix interrupt controller configuration
    irq_handle = fdt.resolve_path("/cpus/cpu@0/interrupt-controller/phandle")[0]
    for i in soc:
        if isinstance(i, FdtNode):
            try:
                compat = i[i.index("compatible")][0]
            except ValueError:
                continue
            if compat in ["riscv,plic0", "riscv,clint0"]:
                if compat == "riscv,plic0":
                    plic0_name = i.get_name()
                elif compat == "riscv,clint0":
                    clint0_name = i.get_name()
                irq_ext = i[i.index("interrupts-extended")]
                new_vals = []
                for u in range(0, len(irq_ext), 2):
                    if irq_ext[u] == irq_handle:
                        new_vals.append(irq_handle)
                        new_vals.append(irq_ext[u+1])
                irq_ext.words = new_vals
    # write dts
    with open(dts_name, "w") as f:
        f.write(fdt.to_dts())

    # build sel4 overlay
    root = FdtNode("/")
    chosen = FdtNode("chosen")
    device_list = ["/soc/" + plic0_name]
    kernel_devices = FdtPropertyStrings("seL4,kernel-devices", device_list)
    chosen.add_subnode(kernel_devices)
    root.add_subnode(chosen)
    fdt = Fdt()
    fdt.add_rootnode(root)
    # write dts
    with open(ovl_name, "w") as f:
        f.write(fdt.to_dts()[9:]) # strip header

def fix_size(x):
    if x < PAGESIZE:
        x = PAGESIZE
    return x


def build_sel4_camkes(dtb, dst_dir):
    camkes_name = os.path.join(dst_dir, "sel4dts.camkes")
    fdt = dtb.to_fdt()
    soc = fdt.resolve_path("/soc")
    s = ""
    for i in soc:
        if not isinstance(i, FdtNode):
            continue
        try:
            compat = i[i.index("compatible")][0]
        except ValueError:
            continue
        if compat in ["zsipos,to_sel4_slave", "zsipos,to_linux_master"]:
            name = i.get_name().split('@')
            name = name[0] + name[1]
            regs = i[i.index("reg")]
            for u in range(3):
                size = fix_size(regs.words[u*2+1])
                s += name + ".reg" + str(u) + "_paddr = " + hex(regs.words[u*2]) + ";\n"
                s += name + ".reg" + str(u) + "_size = " + hex(size) + ";\n"
            irq = i[i.index("interrupts")][0]
            s += name + ".irq_irq_number = " + str(irq) + ";\n"
            s += "\n"
        elif compat == "litex,timer":
            name = i.get_name().split('@')[0]
            regs = i[i.index("reg")]
            size = fix_size(regs.words[1])
            s += name + ".reg_paddr = " + hex(regs.words[0]) + ";\n"
            s += name + ".reg_size = " + hex(size) + ";\n"
            irq = i[i.index("interrupts")][0]
            s += name + ".irq_irq_number = " + str(irq) + ";\n"
            s += "\n"
        elif compat == "litex,liteeth":
            name = i.get_name().split('@')[0]
            if name == "ethmac":
                name += "0"
            regs = i[i.index("reg")]
            for u in range(2):
                size = fix_size(regs.words[u*2+1])
                s += name + ".reg" + str(u) + "_paddr = " + hex(regs.words[u*2]) + ";\n"
                s += name + ".reg" + str(u) + "_size = " + hex(size) + ";\n"
            # we have to generate 2 pages here
            base = regs.words[4];
            s += name + ".reg2_paddr = " + hex(base) + ";\n"
            s += name + ".reg2_size = " + hex(PAGESIZE) + ";\n"
            base += PAGESIZE
            s += name + ".reg3_paddr = " + hex(base) + ";\n"
            s += name + ".reg3_size = " + hex(PAGESIZE) + ";\n"
            irq = i[i.index("interrupts")][0]
            s += name + ".irq_irq_number = " + str(irq) + ";\n"
            s += "\n"

    with open(camkes_name, "w") as f:
        f.write(s)
            
            
def build_dts(src_dts, sel4_size, dst_dir):
    dtb_name = os.path.join(dst_dir, "devicetree.dtb")
    os.spawnlp(os.P_WAIT, "dtc", "dtc", "-q", "-I", "dts", "-O", "dtb", "-o", dtb_name, src_dts)
    with open(dtb_name, "rb") as f:
        dtb = FdtBlobParse(f)
    sel4_size = int(sel4_size, 16)
    build_linux_dts(dtb, sel4_size, dst_dir)
    build_sel4_dts(dtb, sel4_size, dst_dir)
    build_sel4_camkes(dtb, dst_dir)


if __name__ == "__main__":
    if len(sys.argv) != 4:
        sys.exit("usage: mkdts.py <source> <sel4-memsize-hex> <destdir>")
    build_dts(sys.argv[1], sys.argv[2], sys.argv[3])
