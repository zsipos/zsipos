import os

FLASH_BOOT_OFFSET = 0x400000
FLASH_PAYLOAD = os.path.join(
    os.environ["ZTOP"],
    "kernel",
    "build_" + os.environ["BITS"],
    "boot.bin")

FLASH_MAP = {
    FLASH_PAYLOAD:  hex(FLASH_BOOT_OFFSET)
}
