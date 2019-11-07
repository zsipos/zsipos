import os

FLASH_BOOT_ADDRESS = 0x400000
FLASH_PAYLOAD = os.path.join(
    os.environ["TOP"],
    "kernel",
    "build_" + os.environ["BITS"],
    "boot.bin")

FLASH_MAP = {
    FLASH_PAYLOAD:  hex(FLASH_BOOT_ADDRESS)
}
