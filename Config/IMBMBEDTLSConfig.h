#ifndef IMB_MBEDTLS_CONFIG_H
#define IMB_MBEDTLS_CONFIG_H

/* iPad1MailBox: minimal TLS 1.2 client profile for iOS 5.1.1 / armv7.
 * Based on Mbed TLS config-suite-b.h, trimmed to the IMAP client needs.
 */

/* System support */
#define MBEDTLS_HAVE_ASM
#define MBEDTLS_HAVE_TIME
#define MBEDTLS_HAVE_TIME_DATE
#define MBEDTLS_PLATFORM_C

/* iOS 5.x has no clock_gettime(). Provide the monotonic millisecond clock
 * from Classes/IMBMBEDTLSPlatform.c using mach_absolute_time().
 * Mbed TLS requires MBEDTLS_PLATFORM_C together with MBEDTLS_HAVE_TIME for
 * MBEDTLS_PLATFORM_MS_TIME_ALT.
 */
#define MBEDTLS_PLATFORM_MS_TIME_ALT

/* TLS / ECC feature support */
#define MBEDTLS_ECP_DP_SECP256R1_ENABLED
#define MBEDTLS_ECP_DP_SECP384R1_ENABLED
#define MBEDTLS_KEY_EXCHANGE_ECDHE_ECDSA_ENABLED
#define MBEDTLS_SSL_PROTO_TLS1_2

/* Crypto and protocol modules */
#define MBEDTLS_AES_C
#define MBEDTLS_ASN1_PARSE_C
#define MBEDTLS_ASN1_WRITE_C
#define MBEDTLS_BASE64_C
#define MBEDTLS_BIGNUM_C
#define MBEDTLS_CIPHER_C
#define MBEDTLS_CTR_DRBG_C
#define MBEDTLS_ECDH_C
#define MBEDTLS_ECDSA_C
#define MBEDTLS_ECP_C
#define MBEDTLS_ENTROPY_C
#define MBEDTLS_ERROR_C
#define MBEDTLS_GCM_C
#define MBEDTLS_MD_C
#define MBEDTLS_NET_C
#define MBEDTLS_OID_C
#define MBEDTLS_PEM_PARSE_C
#define MBEDTLS_PK_C
#define MBEDTLS_PK_PARSE_C
#define MBEDTLS_PKCS1_V15
#define MBEDTLS_RSA_C
#define MBEDTLS_SHA256_C
#define MBEDTLS_SHA384_C
#define MBEDTLS_SHA512_C
#define MBEDTLS_SSL_CLI_C
#define MBEDTLS_SSL_TLS_C
#define MBEDTLS_X509_CRT_PARSE_C
#define MBEDTLS_X509_USE_C

/*
 * RSA is enabled only so X.509 parsing can recognise/verify RSA PKCS#1 v1.5
 * signatures that may appear on cross-signed CA certificates in the server
 * chain. TLS key exchange remains ECDHE-ECDSA only; no RSA key-exchange suite
 * is enabled below.
 */

/* Low-memory tuning for original iPad (256 MB RAM).
 * 48 bytes is enough for the P-384 EC path. The selected trust anchor is
 * ISRG Root X2 (ECDSA P-384), so a 4096-bit RSA trust-anchor key is not kept
 * in the application trust store.
 */
#define MBEDTLS_AES_ROM_TABLES
#define MBEDTLS_MPI_MAX_SIZE 48
#define MBEDTLS_ECP_WINDOW_SIZE 2
#define MBEDTLS_ECP_FIXED_POINT_OPTIM 0
#define MBEDTLS_ECP_NIST_OPTIM
#define MBEDTLS_ENTROPY_MAX_SOURCES 2

/* The target Dovecot endpoint negotiates one of these modern TLS 1.2 suites. */
#define MBEDTLS_SSL_CIPHERSUITES \
    MBEDTLS_TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384, \
    MBEDTLS_TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256

/* The server currently sends a multi-certificate ECDSA chain larger than 4 KB.
 * Keep this comfortably above that while avoiding the default 16 KB buffers.
 */
#define MBEDTLS_SSL_IN_CONTENT_LEN 8192
#define MBEDTLS_SSL_OUT_CONTENT_LEN 2048

#endif /* IMB_MBEDTLS_CONFIG_H */
