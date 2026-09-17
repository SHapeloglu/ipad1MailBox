#import "IMBMBEDTLSTransport.h"

#include "mbedtls/net_sockets.h"
#include "mbedtls/ssl.h"
#include "mbedtls/entropy.h"
#include "mbedtls/ctr_drbg.h"
#include "mbedtls/x509_crt.h"
#include "mbedtls/error.h"

#include <sys/socket.h>
#include <stdlib.h>
#include <string.h>

NSString * const IMBMBEDTLSTransportErrorDomain = @"com.shapeloglu.ipad1mailbox.mbedtls";

typedef struct {
    mbedtls_net_context serverFD;
    mbedtls_ssl_context ssl;
    mbedtls_ssl_config config;
    mbedtls_x509_crt caCert;
    mbedtls_ctr_drbg_context ctrDRBG;
    mbedtls_entropy_context entropy;
    int initialized;
    int handshakeComplete;
} IMBMBEDTLSContext;

static NSTimeInterval IMBNow(void) {
    return [NSDate timeIntervalSinceReferenceDate];
}

static NSString *IMBMbedTLSErrorText(int code) {
    char buffer[256];
    memset(buffer, 0, sizeof(buffer));
    mbedtls_strerror(code, buffer, sizeof(buffer));
    if (buffer[0] == '\0') {
        return [NSString stringWithFormat:@"Mbed TLS error %d (-0x%04X)",
                code,
                (unsigned int)(-code)];
    }
    return [NSString stringWithFormat:@"%s (%d / -0x%04X)",
            buffer,
            code,
            (unsigned int)(-code)];
}

@implementation IMBMBEDTLSTransport

@synthesize connected = _connected;
@synthesize host = _host;
@synthesize protocolVersion = _protocolVersion;
@synthesize cipherSuite = _cipherSuite;

- (id)init {
    self = [super init];
    if (self) {
        _context = calloc(1, sizeof(IMBMBEDTLSContext));
        _connected = NO;
        _cancelled = NO;
    }
    return self;
}

- (NSError *)errorWithCode:(NSInteger)code description:(NSString *)description {
    NSDictionary *info = [NSDictionary dictionaryWithObject:(description ? description : @"TLS transport error")
                                                      forKey:NSLocalizedDescriptionKey];
    return [NSError errorWithDomain:IMBMBEDTLSTransportErrorDomain code:code userInfo:info];
}

- (void)assignError:(NSError **)error code:(NSInteger)code description:(NSString *)description {
    if (error) *error = [self errorWithCode:code description:description];
}

- (IMBMBEDTLSContext *)tlsContext {
    return (IMBMBEDTLSContext *)_context;
}

- (void)initializeTLSContext {
    IMBMBEDTLSContext *ctx = [self tlsContext];
    if (!ctx || ctx->initialized) return;

    mbedtls_net_init(&ctx->serverFD);
    mbedtls_ssl_init(&ctx->ssl);
    mbedtls_ssl_config_init(&ctx->config);
    mbedtls_x509_crt_init(&ctx->caCert);
    mbedtls_ctr_drbg_init(&ctx->ctrDRBG);
    mbedtls_entropy_init(&ctx->entropy);
    ctx->initialized = 1;
    ctx->handshakeComplete = 0;
}

- (void)freeTLSContext {
    IMBMBEDTLSContext *ctx = [self tlsContext];
    if (!ctx || !ctx->initialized) return;

    if (ctx->handshakeComplete && !_cancelled) {
        mbedtls_ssl_close_notify(&ctx->ssl);
    }
    mbedtls_net_free(&ctx->serverFD);
    mbedtls_x509_crt_free(&ctx->caCert);
    mbedtls_ssl_free(&ctx->ssl);
    mbedtls_ssl_config_free(&ctx->config);
    mbedtls_ctr_drbg_free(&ctx->ctrDRBG);
    mbedtls_entropy_free(&ctx->entropy);

    memset(ctx, 0, sizeof(IMBMBEDTLSContext));
    _connected = NO;
}

- (BOOL)loadTrustAnchorIntoContext:(IMBMBEDTLSContext *)ctx error:(NSError **)error {
    NSString *caPath = [[NSBundle mainBundle] pathForResource:@"isrgrootx1" ofType:@"pem"];
    if ([caPath length] == 0) {
        [self assignError:error
                     code:IMBMBEDTLSTransportErrorCertificate
              description:@"Bundled ISRG Root X1 trust anchor is missing."];
        return NO;
    }

    NSData *caData = [NSData dataWithContentsOfFile:caPath];
    if ([caData length] == 0) {
        [self assignError:error
                     code:IMBMBEDTLSTransportErrorCertificate
              description:@"Unable to read bundled ISRG Root X1 trust anchor."];
        return NO;
    }

    unsigned char *buffer = (unsigned char *)calloc([caData length] + 1, 1);
    if (!buffer) {
        [self assignError:error
                     code:IMBMBEDTLSTransportErrorGeneric
              description:@"Out of memory while loading TLS trust anchor."];
        return NO;
    }

    memcpy(buffer, [caData bytes], [caData length]);
    int ret = mbedtls_x509_crt_parse(&ctx->caCert, buffer, [caData length] + 1);
    free(buffer);

    if (ret < 0) {
        [self assignError:error
                     code:IMBMBEDTLSTransportErrorCertificate
              description:[NSString stringWithFormat:@"Unable to parse TLS trust anchor: %@",
                           IMBMbedTLSErrorText(ret)]];
        return NO;
    }
    return YES;
}

- (BOOL)checkCancelled:(NSError **)error {
    if (!_cancelled) return NO;
    [self assignError:error
                 code:IMBMBEDTLSTransportErrorCancelled
          description:@"TLS operation was cancelled."];
    return YES;
}

- (BOOL)connectToHost:(NSString *)host
                 port:(NSUInteger)port
              timeout:(NSTimeInterval)timeout
                error:(NSError **)error {
    [self close];

    if ([host length] == 0 || port == 0) {
        [self assignError:error
                     code:IMBMBEDTLSTransportErrorGeneric
              description:@"TLS host or port is missing."];
        return NO;
    }

    _cancelled = NO;
    [_host release];
    _host = [host copy];
    [_protocolVersion release];
    _protocolVersion = nil;
    [_cipherSuite release];
    _cipherSuite = nil;

    [self initializeTLSContext];
    IMBMBEDTLSContext *ctx = [self tlsContext];
    if (!ctx) {
        [self assignError:error
                     code:IMBMBEDTLSTransportErrorGeneric
              description:@"Unable to allocate TLS context."];
        return NO;
    }

    const char *personalization = "iPad1MailBox-transport";
    int ret = mbedtls_ctr_drbg_seed(&ctx->ctrDRBG,
                                    mbedtls_entropy_func,
                                    &ctx->entropy,
                                    (const unsigned char *)personalization,
                                    strlen(personalization));
    if (ret != 0) {
        [self assignError:error
                     code:IMBMBEDTLSTransportErrorGeneric
              description:[NSString stringWithFormat:@"TLS RNG initialization failed: %@",
                           IMBMbedTLSErrorText(ret)]];
        [self freeTLSContext];
        return NO;
    }

    if (![self loadTrustAnchorIntoContext:ctx error:error]) {
        [self freeTLSContext];
        return NO;
    }

    char portText[16];
    snprintf(portText, sizeof(portText), "%lu", (unsigned long)port);
    ret = mbedtls_net_connect(&ctx->serverFD,
                              [host UTF8String],
                              portText,
                              MBEDTLS_NET_PROTO_TCP);
    if (ret != 0) {
        [self assignError:error
                     code:IMBMBEDTLSTransportErrorGeneric
              description:[NSString stringWithFormat:@"TCP connection failed: %@",
                           IMBMbedTLSErrorText(ret)]];
        [self freeTLSContext];
        return NO;
    }

    if ([self checkCancelled:error]) {
        [self freeTLSContext];
        return NO;
    }

    ret = mbedtls_ssl_config_defaults(&ctx->config,
                                      MBEDTLS_SSL_IS_CLIENT,
                                      MBEDTLS_SSL_TRANSPORT_STREAM,
                                      MBEDTLS_SSL_PRESET_DEFAULT);
    if (ret != 0) {
        [self assignError:error
                     code:IMBMBEDTLSTransportErrorGeneric
              description:[NSString stringWithFormat:@"TLS configuration failed: %@",
                           IMBMbedTLSErrorText(ret)]];
        [self freeTLSContext];
        return NO;
    }

    mbedtls_ssl_conf_authmode(&ctx->config, MBEDTLS_SSL_VERIFY_REQUIRED);
    mbedtls_ssl_conf_ca_chain(&ctx->config, &ctx->caCert, NULL);
    mbedtls_ssl_conf_rng(&ctx->config, mbedtls_ctr_drbg_random, &ctx->ctrDRBG);
    mbedtls_ssl_conf_read_timeout(&ctx->config, 1000);

    ret = mbedtls_ssl_setup(&ctx->ssl, &ctx->config);
    if (ret != 0) {
        [self assignError:error
                     code:IMBMBEDTLSTransportErrorGeneric
              description:[NSString stringWithFormat:@"TLS setup failed: %@",
                           IMBMbedTLSErrorText(ret)]];
        [self freeTLSContext];
        return NO;
    }

    ret = mbedtls_ssl_set_hostname(&ctx->ssl, [host UTF8String]);
    if (ret != 0) {
        [self assignError:error
                     code:IMBMBEDTLSTransportErrorGeneric
              description:[NSString stringWithFormat:@"TLS hostname/SNI setup failed: %@",
                           IMBMbedTLSErrorText(ret)]];
        [self freeTLSContext];
        return NO;
    }

    mbedtls_ssl_set_bio(&ctx->ssl,
                        &ctx->serverFD,
                        mbedtls_net_send,
                        mbedtls_net_recv,
                        mbedtls_net_recv_timeout);

    NSTimeInterval deadline = IMBNow() + ((timeout > 0.0) ? timeout : 20.0);
    while ((ret = mbedtls_ssl_handshake(&ctx->ssl)) != 0) {
        if ([self checkCancelled:error]) {
            [self freeTLSContext];
            return NO;
        }

        if (ret == MBEDTLS_ERR_SSL_WANT_READ ||
            ret == MBEDTLS_ERR_SSL_WANT_WRITE ||
            ret == MBEDTLS_ERR_SSL_TIMEOUT) {
            if (IMBNow() < deadline) continue;
            [self assignError:error
                         code:IMBMBEDTLSTransportErrorTimeout
                  description:@"TLS handshake timed out."];
            [self freeTLSContext];
            return NO;
        }

        [self assignError:error
                     code:IMBMBEDTLSTransportErrorCertificate
              description:[NSString stringWithFormat:@"TLS handshake failed: %@",
                           IMBMbedTLSErrorText(ret)]];
        [self freeTLSContext];
        return NO;
    }

    uint32_t verifyFlags = mbedtls_ssl_get_verify_result(&ctx->ssl);
    if (verifyFlags != 0) {
        char verifyInfo[768];
        memset(verifyInfo, 0, sizeof(verifyInfo));
        mbedtls_x509_crt_verify_info(verifyInfo,
                                     sizeof(verifyInfo) - 1,
                                     "",
                                     verifyFlags);
        [self assignError:error
                     code:IMBMBEDTLSTransportErrorCertificate
              description:[NSString stringWithFormat:@"TLS certificate verification failed: %s",
                           verifyInfo]];
        [self freeTLSContext];
        return NO;
    }

    ctx->handshakeComplete = 1;
    _connected = YES;
    _protocolVersion = [[NSString alloc] initWithUTF8String:mbedtls_ssl_get_version(&ctx->ssl)];
    _cipherSuite = [[NSString alloc] initWithUTF8String:mbedtls_ssl_get_ciphersuite(&ctx->ssl)];
    return YES;
}

- (BOOL)writeData:(NSData *)data
          timeout:(NSTimeInterval)timeout
            error:(NSError **)error {
    if (!_connected || !data) {
        [self assignError:error
                     code:IMBMBEDTLSTransportErrorClosed
              description:@"TLS connection is not open."];
        return NO;
    }

    IMBMBEDTLSContext *ctx = [self tlsContext];
    const unsigned char *bytes = (const unsigned char *)[data bytes];
    NSUInteger total = [data length];
    NSUInteger offset = 0;
    NSTimeInterval deadline = IMBNow() + ((timeout > 0.0) ? timeout : 20.0);

    while (offset < total) {
        if ([self checkCancelled:error]) return NO;

        int ret = mbedtls_ssl_write(&ctx->ssl,
                                    bytes + offset,
                                    total - offset);
        if (ret > 0) {
            offset += (NSUInteger)ret;
            continue;
        }

        if (ret == MBEDTLS_ERR_SSL_WANT_READ ||
            ret == MBEDTLS_ERR_SSL_WANT_WRITE ||
            ret == MBEDTLS_ERR_SSL_TIMEOUT) {
            if (IMBNow() < deadline) continue;
            [self assignError:error
                         code:IMBMBEDTLSTransportErrorTimeout
                  description:@"TLS write timed out."];
            return NO;
        }

        [self assignError:error
                     code:IMBMBEDTLSTransportErrorGeneric
              description:[NSString stringWithFormat:@"TLS write failed: %@",
                           IMBMbedTLSErrorText(ret)]];
        return NO;
    }

    return YES;
}

- (NSInteger)readBytes:(uint8_t *)buffer
             maxLength:(NSUInteger)maxLength
               timeout:(NSTimeInterval)timeout
                 error:(NSError **)error {
    if (!_connected || !buffer || maxLength == 0) {
        [self assignError:error
                     code:IMBMBEDTLSTransportErrorClosed
              description:@"TLS connection is not open."];
        return -1;
    }

    IMBMBEDTLSContext *ctx = [self tlsContext];
    NSTimeInterval deadline = IMBNow() + ((timeout > 0.0) ? timeout : 20.0);

    for (;;) {
        if ([self checkCancelled:error]) return -1;

        int ret = mbedtls_ssl_read(&ctx->ssl, buffer, maxLength);
        if (ret > 0) return (NSInteger)ret;
        if (ret == 0 || ret == MBEDTLS_ERR_SSL_PEER_CLOSE_NOTIFY) return 0;

        if (ret == MBEDTLS_ERR_SSL_WANT_READ ||
            ret == MBEDTLS_ERR_SSL_WANT_WRITE ||
            ret == MBEDTLS_ERR_SSL_TIMEOUT) {
            if (IMBNow() < deadline) continue;
            [self assignError:error
                         code:IMBMBEDTLSTransportErrorTimeout
                  description:@"TLS read timed out."];
            return -1;
        }

        [self assignError:error
                     code:IMBMBEDTLSTransportErrorGeneric
              description:[NSString stringWithFormat:@"TLS read failed: %@",
                           IMBMbedTLSErrorText(ret)]];
        return -1;
    }
}

- (void)cancel {
    _cancelled = YES;
    IMBMBEDTLSContext *ctx = [self tlsContext];
    if (ctx && ctx->initialized && ctx->serverFD.fd >= 0) {
        shutdown(ctx->serverFD.fd, SHUT_RDWR);
    }
}

- (void)close {
    [self freeTLSContext];
    _cancelled = NO;
}

- (void)dealloc {
    [self cancel];
    [self freeTLSContext];
    if (_context) free(_context);
    [_host release];
    [_protocolVersion release];
    [_cipherSuite release];
    [super dealloc];
}

@end
