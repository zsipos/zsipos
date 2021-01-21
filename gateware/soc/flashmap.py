# SPDX-FileCopyrightText: 2019 Stefan Adams <stefan.adams@vipcomag.de>
# SPDX-License-Identifier: GPL-3.0-or-later

import os

ZTOP = os.environ["ZTOP"]

FLASH_BITSTREAM_OFFSET = 0x0
FLASH_BITSTREAM_IMAGE = os.path.join(
    ZTOP, "gateware", "soc", "build" + "_" + os.environ["BOARD"], "gateware", "zsipos.bit")

FLASH_BOOTROM_OFFSET = 0x400000
FLASH_BOOTROM_IMAGE = os.path.join(
    ZTOP, "kernel", "build_" + os.environ["BITS"], "u-boot", "u-boot.bin")

FLASH_MAP = {
    FLASH_BITSTREAM_OFFSET :  (FLASH_BITSTREAM_IMAGE, "bit" , False),
    FLASH_BOOTROM_OFFSET   :  (FLASH_BOOTROM_IMAGE  , "data", True )
}
