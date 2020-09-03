// SPDX-FileCopyrightText: 2019 Stefan Adams <stefan.adams@vipcomag.de>
// SPDX-License-Identifier: GPL-3.0-or-later

#ifdef __or1k__
extern "C" int ocaes_init_zrtp(void);
extern "C" int swsha1_init_zrtp(void);
#endif
static pj_status_t init_crypt_engine()
{
#ifdef __or1k__
	ocaes_init_zrtp();
	swsha1_init_zrtp();
#endif
	return PJ_SUCCESS;
}

static void clog(const char *sender, int level, const char *fmt, ...)
{
	va_list args;

	va_start(args, fmt);
	pj_log(sender, level, fmt, args);
}
