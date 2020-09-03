# SPDX-FileCopyrightText: 2019 Stefan Adams <stefan.adams@vipcomag.de>
# SPDX-License-Identifier: GPL-3.0-or-later

LIBZRTPCPP_DIR      = $(ZTOP)/software/zrtpcpp
LIBZRTPCPP_INCLUDES = -I$(LIBZRTPCPP_DIR) -I$(LIBZRTPCPP_DIR)/srtp -I$(LIBZRTPCPP_DIR)/zrtp
LIBZRTPCPP_LIBS     = -lzrtpcppcore


CFLAGS_COMMON += $(LIBZRTPCPP_INCLUDES)
LIBS_COMMON   += $(LIBZRTPCPP_LIBS)

#
# zsipos
#
LDFLAGS_ZSIPOS += -L$(ZTOP)/software/build_zsipos/zrtpcpp/clients/no_client

#
# host
#
LDFLAGS_HOST += -L$(ZTOP)/software/build_host/zrtpcpp/clients/no_client



