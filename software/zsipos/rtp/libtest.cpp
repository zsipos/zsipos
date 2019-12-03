#include <stdio.h>
#include <string.h>
#include <stdint.h>
#include <time.h>
#include <libzrtpcpp/zrtpPacket.h>
#include <libzrtpcpp/ZRtp.h>
#include <cryptcommon/aescpp.h>
#include <srtp/CryptoContext.h>
#include <srtp/SrtpHandler.h>
#include <openssl/hmac.h>
#include <openssl/sha.h>
#include <crypto/hmac256.h>
#include <pjlib.h>
#include <pjmedia/alaw_ulaw.h>
#include "rtp.h"

const char *protect_str = "80001700e60502e2207879fffcfbfd7ffc7efef8fd7b75767cfefdff7e7d7b7efffdfb7e79797fff7dfcf9f6f9fdfe7efcf8fc7d777d7c7773747a7e7b797b7d7c76777bfffcfffdf8f7fbfefeff7e7ef7f6fefffdf8fc7b7a7b7979fef8f4f6f9faf9faf2eff2f2f2f3f4faf7fbfaf8f5f8ff7a7dfdfc79797d7c7b7cff7a767372727177787c7e7975787776797dff7ffe7e7d7c797bfffafcfffbf8f8fe7b7b7d7d7b7d7f7a73";
const char *hmac256_key = "02c2ee6fd2856496d7f37316c4f7e1ebf80408366d5d70b864fa147f09bb873a";
const char *hmac256_str = "505a002544485061727432203efe71ad83d1df770d9868fc6a22ce7c3c4bffb63dd15da798e3921f10d6912b4a2e90e97347d635699a8235fbaffbeb7f87370cb72543c8d182fe8cb5ef241fe3caef3e94ae0a94c5d0e3dd1ff98f180f26e46a01ac9fcd761ecffddb21a3bd8c9b7c14dc4dd9a5eaa092fa3ed2b3f540ef5b574b8ca8b2e405eb893821b2de";
const char *hmac256_ok = "fe979d454ee2eb67";

#define prs(x) printf("sizeof(%s)=%ld\n", #x, sizeof(x))

static uint8_t key[16];
static uint8_t salt[14];

static void debugout(const char *msg, uint8_t *data, int l)
{
	int i;

	printf("%s", msg);
	for (i = 0; i < l; i++)
		printf("%02x", data[i]);
	printf("\n");
}

void parse(const char *str, uint8_t *data, size_t *len)
{
	int i;

	*len = strlen(str)/2;
	for (i = 0; i < *len; i++) {
		int c;
		sscanf(&str[i*2], "%02x", &c);
		data[i] = c;
	}
}

int main(int argc, char **argv)
{
	uint8_t data[4096];
	size_t l, nl, i;
	uint32_t ml;
	uint8_t kdata[HASH_IMAGE_SIZE];
	uint8_t hmac256_res[HMAC_SIZE + 20];
	uint32_t hmac256_len;
	time_t start;
	HMAC_CTX *ctx;
	uint8_t v1, v2;

    init_crypt_engine();

#if 0
	prs(zrtpPacketHeader_t);
	prs(Hello_t);
	prs(HelloPacket_t);
	prs(HelloAckPacket_t);
	prs(Commit_t);
	prs(CommitPacket_t);
	prs(DHPart_t);
	prs(DHPartPacket_t);
	prs(Confirm_t);
	prs(ConfirmPacket_t);
	prs(Conf2AckPacket_t);
	prs(GoClear_t);
	prs(GoClearPacket_t);
	prs(ClearAckPacket_t);
	prs(Error_t);
	prs(ErrorPacket_t);
	prs(ErrorAckPacket_t);
	prs(Ping_t);
	prs(PingPacket_t);
	prs(PingAck_t);
	prs(PingAckPacket_t);
	prs(SASrelay_t);
	prs(SASrelayPacket_t);
	prs(RelayAckPacket_t);

	printf("protect/unprotect test\n");
	parse(protect_str, data, &l);
	debugout("input:", data, l);

	CryptoContext *c =
        new CryptoContext(0,                                       // SSRC (used for lookup)
                          0,                                       // Roll-Over-Counter (ROC)
                          0L,                                      // keyderivation << 48,
						  SrtpEncryptionAESCM,                     // encryption algo
						  SrtpAuthenticationSha1Hmac,              // authtentication algo
                          key,                                     // Master Key
                          sizeof(key),		                       // Master Key length
                          salt,                                    // Master Salt
                          sizeof(salt),                            // Master Salt length
                          sizeof(key),                             // encryption keyl
                          20,                                      // authentication key len
                          sizeof(salt),                            // session salt len
                          32 / 8);                                 // authentication tag lenA
	if (!c) {
		printf("no crypto context.");
		exit(1);
	}
	c->deriveSrtpKeys(0);

	SrtpHandler::protect(c, data, l, &nl);
	debugout("protect:", data, nl);
	SrtpHandler::unprotect(c, data, nl, &l, NULL);
	debugout("unprotect:", data, l);

	printf("hmac256 test:\n");
	parse(hmac256_key, kdata, &l);
	parse(hmac256_str, data, &l);
    hmac_sha256(kdata, HASH_IMAGE_SIZE, data, l, hmac256_res, &hmac256_len);
    printf("hash=");
    for (i = 0; i < HMAC_SIZE; i++)
    	printf("%02x", hmac256_res[i]);
    printf(" -- %s\n", hmac256_ok);
#endif

#if 0
    memset(data, 0, sizeof(data));
    nl = 3;
    printf("sha1 test:\n");
    time(&start);
    SHA1(data, nl, hmac256_res);
    for (i = 0; i < 20; i++)
    	printf("%02x", hmac256_res[i]);
    printf("\n");
	printf("%d\n", (int)(time(0) - start));
	printf("hmac-sha1 test:\n");
	void *v;
	memset(hmac256_res, 0, 20);
	hmac256_len = 0;
	const uint8_t *_data[] = { data, NULL };
	uint32_t _data_length[] = { (uint32_t)nl, 0 };
    time(&start);
	v = initializeSha1HmacContext(&ctx, (uint8_t*)"abc", 3);
	hmacSha1Ctx(v, _data, _data_length, hmac256_res, (int32_t*)&hmac256_len);
	for (i = 0; i < hmac256_len; i++)
		printf("%02x", hmac256_res[i]);
	printf("\n");
	hmacSha1Ctx(v, _data, _data_length, hmac256_res, (int32_t*)&hmac256_len);
	for (i = 0; i < hmac256_len; i++)
		printf("%02x", hmac256_res[i]);
	printf("\n");
	printf("%d\n", (int)(time(0) - start));

#endif

#if 1
	printf("uint8_t zsipos_a2u[] = {");
	for (i = 0; i < 256; i++)
		printf("0x%02x,", pjmedia_linear2ulaw(pjmedia_alaw2linear(i)));
	printf("};\n");
	printf("uint8_t zsipos_u2a[] = {");
	for (i = 0; i < 256; i++)
		printf("0x%02x,", pjmedia_linear2alaw(pjmedia_ulaw2linear(i)));
	printf("};\n");

	printf("uint8_t zsipos_alaw0 = 0x%02x;\n", pjmedia_linear2alaw(0));
	printf("uint8_t zsipos_ulaw0 = 0x%02x;\n", pjmedia_linear2ulaw(0));
#endif


#if 0
	for (v1 = 0; ; v1++) {
		v2 = pjmedia_alaw2ulaw(v1);
		printf("%02x,%02x,%02x\n", v1, v2, pjmedia_ulaw2alaw(v2));
		if (v1 != pjmedia_ulaw2alaw(v2)) {
			printf("ERROR a2u\n");
		}
		if (v1 == 255) break;
	}
	for (v1 = 0; ; v1++) {
		v2 = pjmedia_ulaw2alaw(v1);
		printf("%02x,%02x,%02x\n", v1, v2, pjmedia_alaw2ulaw(v2));
		if (v1 != pjmedia_alaw2ulaw(v2)) {
			printf("ERROR u2a\n");
		}
		if (v1 == 255) break;
	}
#endif

    return 0;
}
