LIBPJ_DIR      = $(ZTOP)/software/pjproject
LIBPJ_INCLUDES = -I$(LIBPJ_DIR)/pjmedia/include \
		 -I$(LIBPJ_DIR)/pjnath/include \
                 -I$(LIBPJ_DIR)/pjlib-util/include \
		 -I$(LIBPJ_DIR)/pjlib/include
LIBPJ_LIBS_TPL = $(LIBPJ_DIR)/pjmedia/lib/libpjmedia-TPL.a \
		 $(LIBPJ_DIR)/pjnath/lib/libpjnath-TPL.a \
		 $(LIBPJ_DIR)/pjlib-util/lib/libpjlib-util-TPL.a \
		 $(LIBPJ_DIR)/pjlib/lib/libpj-TPL.a

CFLAGS_COMMON += $(LIBPJ_INCLUDES) -DPJ_AUTOCONF=1

#
# zsipos
#
LIBS_ZSIPOS += $(subst -TPL,-riscv64-unknown-linux-gnu,$(LIBPJ_LIBS_TPL))

#
# host
#
LIBS_HOST += $(subst -TPL,-x86_64-unknown-linux-gnu,$(LIBPJ_LIBS_TPL))



