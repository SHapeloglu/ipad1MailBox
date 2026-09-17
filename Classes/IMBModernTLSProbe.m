#import "IMBModernTLSProbe.h"

#include "mbedtls/net_sockets.h"
#include "mbedtls/ssl.h"
#include "mbedtls/entropy.h"
#include "mbedtls/ctr_drbg.h"
#include "mbedtls/x509_crt.h"
#include "mbedtls/error.h"

#include <stdlib.h>
#include <string.h>

@implementation IMBModernTLSProbe

+ (NSString *)errorTextForCode:(int)code {
    char buffer[256];
    memset(buffer, 0, sizeof(buffer));
    mbedtls_strerror(code, buffer, sizeof(buffer));
    if (buffer[0] == '\0') {
        return [NSString stringWithFormat:@"Mbed TLS error %d (-0x%04X)", code, (unsigned int)(-code)];
    }
    return [NSString stringWithFormat:@"%s (%d / -0x%04X)", buffer, code, (unsigned int)(-code)];
}

+ (void)runForHost:(NSString *)host
              port:(NSUInteger)port
            target:(id)target
          selector:(SEL)selector {
    if ([host length] == 0 || !target || !selector) return;

    NSDictionary *arguments = [[NSDictionary alloc] initWithObjectsAndKeys:
                               host, @"host",
                               [NSNumber numberWithUnsignedInteger:port], @"port",
                               target, @"target",
                               NSStringFromSelector(selector), @"selector",
                               nil];
    [NSThread detachNewThreadSelector:@selector(runWorker:)
                             toTarget:self
                           withObject:arguments];
    [arguments release];
}

+ (void)runWorker:(NSDictionary *)arguments {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

    NSString *host = [arguments objectForKey:@"host"];
    NSUInteger port = [[arguments objectForKey:@"port"] unsignedIntegerValue];
    id target = [arguments objectForKey:@"target"];
    SEL selector = NSSelectorFromString([arguments objectForKey:@"selector"]);

    NSString *report = [self synchronousReportForHost:host port:port];
    if (target && selector && [target respondsToSelector:selector]) {
        [target performSelectorOnMainThread:selector withObject:report waitUntilDone:NO];
    }

    [pool drain];
}

+ (NSString *)synchronousReportForHost:(NSString *)host port:(NSUInteger)port {
    NSMutableString *report = [NSMutableString string];
    [report appendString:@"Modern TLS probe (Mbed TLS 3.6.7)\n"];
    [report appendFormat:@"Target: %@:%lu\n\n", host, (unsigned long)port];

    int ret = 0;
    int handshakeComplete = 0;
    uint32_t verifyFlags = 0;
    mbedtls_net_context serverFD;
    mbedtls_ssl_context ssl;
    mbedtls_ssl_config config;
    mbedtls_x509_crt caCert;
    mbedtls_ctr_drbg_context ctrDRBG;
    mbedtls_entropy_context entropy;

    mbedtls_net_init(&serverFD);
    mbedtls_ssl_init(&ssl);
    mbedtls_ssl_config_init(&config);
    mbedtls_x509_crt_init(&caCert);
    mbedtls_ctr_drbg_init(&ctrDRBG);
    mbedtls_entropy_init(&entropy);

    const char *personalization = "iPad1MailBox-modern-tls";
    ret = mbedtls_ctr_drbg_seed(&ctrDRBG,
                                mbedtls_entropy_func,
                                &entropy,
                                (const unsigned char *)personalization,
                                strlen(personalization));
    if (ret != 0) {
        [report appendFormat:@"RNG seed: FAILED\n%@\n", [self errorTextForCode:ret]];
        goto cleanup;
    }
    [report appendString:@"RNG seed: OK\n"];

    NSString *caPath = [[NSBundle mainBundle] pathForResource:@"isrgrootx1" ofType:@"pem"];
    if ([caPath length] == 0) {
        [report appendString:@"CA trust anchor: FAILED\nResources/isrgrootx1.pem is missing.\n"];
        goto cleanup;
    }

    NSData *caData = [NSData dataWithContentsOfFile:caPath];
    if ([caData length] == 0) {
        [report appendString:@"CA trust anchor: FAILED\nUnable to read ISRG Root X1.\n"];
        goto cleanup;
    }

    unsigned char *caBuffer = (unsigned char *)calloc([caData length] + 1, 1);
    if (!caBuffer) {
        [report appendString:@"CA trust anchor: FAILED\nOut of memory.\n"];
        goto cleanup;
    }
    memcpy(caBuffer, [caData bytes], [caData length]);
    ret = mbedtls_x509_crt_parse(&caCert, caBuffer, [caData length] + 1);
    free(caBuffer);
    caBuffer = NULL;
    if (ret < 0) {
        [report appendFormat:@"CA trust anchor: FAILED\n%@\n", [self errorTextForCode:ret]];
        goto cleanup;
    }
    [report appendString:@"CA trust anchor: ISRG Root X1 loaded\n"];

    char portText[16];
    snprintf(portText, sizeof(portText), "%lu", (unsigned long)port);
    [report appendString:@"TCP connect: "];
    ret = mbedtls_net_connect(&serverFD,
                              [host UTF8String],
                              portText,
                              MBEDTLS_NET_PROTO_TCP);
    if (ret != 0) {
        [report appendFormat:@"FAILED\n%@\n", [self errorTextForCode:ret]];
        goto cleanup;
    }
    [report appendString:@"OK\n"];

    ret = mbedtls_ssl_config_defaults(&config,
                                      MBEDTLS_SSL_IS_CLIENT,
                                      MBEDTLS_SSL_TRANSPORT_STREAM,
                                      MBEDTLS_SSL_PRESET_DEFAULT);
    if (ret != 0) {
        [report appendFormat:@"TLS config: FAILED\n%@\n", [self errorTextForCode:ret]];
        goto cleanup;
    }

    mbedtls_ssl_conf_authmode(&config, MBEDTLS_SSL_VERIFY_REQUIRED);
    mbedtls_ssl_conf_ca_chain(&config, &caCert, NULL);
    mbedtls_ssl_conf_rng(&config, mbedtls_ctr_drbg_random, &ctrDRBG);

    ret = mbedtls_ssl_setup(&ssl, &config);
    if (ret != 0) {
        [report appendFormat:@"TLS setup: FAILED\n%@\n", [self errorTextForCode:ret]];
        goto cleanup;
    }

    ret = mbedtls_ssl_set_hostname(&ssl, [host UTF8String]);
    if (ret != 0) {
        [report appendFormat:@"SNI/hostname: FAILED\n%@\n", [self errorTextForCode:ret]];
        goto cleanup;
    }
    [report appendFormat:@"SNI/hostname: %@\n", host];

    mbedtls_ssl_set_bio(&ssl,
                        &serverFD,
                        mbedtls_net_send,
                        mbedtls_net_recv,
                        NULL);

    [report appendString:@"TLS handshake: "];
    while ((ret = mbedtls_ssl_handshake(&ssl)) != 0) {
        if (ret != MBEDTLS_ERR_SSL_WANT_READ && ret != MBEDTLS_ERR_SSL_WANT_WRITE) {
            [report appendFormat:@"FAILED\n%@\n", [self errorTextForCode:ret]];
            verifyFlags = mbedtls_ssl_get_verify_result(&ssl);
            if (verifyFlags != 0) {
                char verifyInfo[768];
                memset(verifyInfo, 0, sizeof(verifyInfo));
                mbedtls_x509_crt_verify_info(verifyInfo, sizeof(verifyInfo), "  ", verifyFlags);
                [report appendFormat:@"Certificate verify flags: 0x%08lX\n%s\n",
                 (unsigned long)verifyFlags,
                 verifyInfo];
            }
            goto cleanup;
        }
    }
    handshakeComplete = 1;
    [report appendString:@"OK\n"];

    [report appendFormat:@"Protocol: %s\n", mbedtls_ssl_get_version(&ssl)];
    [report appendFormat:@"Cipher: %s\n", mbedtls_ssl_get_ciphersuite(&ssl)];

    verifyFlags = mbedtls_ssl_get_verify_result(&ssl);
    if (verifyFlags == 0) {
        [report appendString:@"Certificate verification: OK\n"];
    } else {
        char verifyInfo[768];
        memset(verifyInfo, 0, sizeof(verifyInfo));
        mbedtls_x509_crt_verify_info(verifyInfo, sizeof(verifyInfo), "  ", verifyFlags);
        [report appendFormat:@"Certificate verification: FAILED (0x%08lX)\n%s\n",
         (unsigned long)verifyFlags,
         verifyInfo];
        goto cleanup;
    }

    const mbedtls_x509_crt *peer = mbedtls_ssl_get_peer_cert(&ssl);
    if (peer) {
        char subject[512];
        char issuer[512];
        memset(subject, 0, sizeof(subject));
        memset(issuer, 0, sizeof(issuer));
        mbedtls_x509_dn_gets(subject, sizeof(subject), &peer->subject);
        mbedtls_x509_dn_gets(issuer, sizeof(issuer), &peer->issuer);
        [report appendFormat:@"Peer subject: %s\n", subject];
        [report appendFormat:@"Peer issuer: %s\n", issuer];
    }

    [report appendString:@"\nIMAP greeting: "];
    unsigned char input[1024];
    memset(input, 0, sizeof(input));
    do {
        ret = mbedtls_ssl_read(&ssl, input, sizeof(input) - 1);
    } while (ret == MBEDTLS_ERR_SSL_WANT_READ || ret == MBEDTLS_ERR_SSL_WANT_WRITE);

    if (ret > 0) {
        input[ret] = '\0';
        NSString *greeting = [[[NSString alloc] initWithBytes:input
                                                      length:(NSUInteger)ret
                                                    encoding:NSUTF8StringEncoding] autorelease];
        if (!greeting) greeting = [[[NSString alloc] initWithBytes:input
                                                            length:(NSUInteger)ret
                                                          encoding:NSISOLatin1StringEncoding] autorelease];
        NSRange lineEnd = [greeting rangeOfString:@"\r\n"];
        if (lineEnd.location != NSNotFound) greeting = [greeting substringToIndex:lineEnd.location];
        [report appendFormat:@"%@\n", greeting ? greeting : @"(unreadable)"];
    } else {
        [report appendFormat:@"FAILED\n%@\n", [self errorTextForCode:ret]];
    }

cleanup:
    if (handshakeComplete) {
        mbedtls_ssl_close_notify(&ssl);
    }
    mbedtls_net_free(&serverFD);
    mbedtls_x509_crt_free(&caCert);
    mbedtls_ssl_free(&ssl);
    mbedtls_ssl_config_free(&config);
    mbedtls_ctr_drbg_free(&ctrDRBG);
    mbedtls_entropy_free(&entropy);

    return report;
}

@end
