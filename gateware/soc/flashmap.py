import os

ZTOP = os.environ["ZTOP"]

FLASH_BITSTREAM_OFFSET = 0x0
FLASH_BITSTREAM_IMAGE = os.path.join(
    ZTOP, "gateware", "soc", "build" + "_" + os.environ["BOARD"], "gateware", "top.bit")

FLASH_BOOTROM_OFFSET = 0x400000
FLASH_BOOTROM_IMAGE = os.path.join(
    ZTOP, "kernel", "build_" + os.environ["BITS"], "bbl", "bbl.bin")

FLASH_MAP = {
    FLASH_BITSTREAM_OFFSET :  (FLASH_BITSTREAM_IMAGE, "bit" , False),
    FLASH_BOOTROM_OFFSET   :  (FLASH_BOOTROM_IMAGE  , "data", True )
}
