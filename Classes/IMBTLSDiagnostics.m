#import "IMBTLSDiagnostics.h"
#import <Security/SecureTransport.h>
#include <stdlib.h>

@implementation IMBTLSDiagnostics

+ (BOOL)cipher:(SSLCipherSuite)cipher isPresentInList:(SSLCipherSuite *)list count:(size_t)count {
    if (!list || count == 0) return NO;
    size_t i;
    for (i = 0; i < count; i++) {
        if (list[i] == cipher) return YES;
    }
    return NO;
}

+ (NSString *)nameForCipher:(SSLCipherSuite)cipher {
    switch (cipher) {
        case 0x0005: return @"TLS_RSA_WITH_RC4_128_SHA";
        case 0x002F: return @"TLS_RSA_WITH_AES_128_CBC_SHA";
        case 0x0035: return @"TLS_RSA_WITH_AES_256_CBC_SHA";
        case 0x003C: return @"TLS_RSA_WITH_AES_128_CBC_SHA256";
        case 0x003D: return @"TLS_RSA_WITH_AES_256_CBC_SHA256";
        case 0xC007: return @"TLS_ECDHE_ECDSA_WITH_RC4_128_SHA";
        case 0xC009: return @"TLS_ECDHE_ECDSA_WITH_AES_128_CBC_SHA";
        case 0xC00A: return @"TLS_ECDHE_ECDSA_WITH_AES_256_CBC_SHA";
        case 0xC011: return @"TLS_ECDHE_RSA_WITH_RC4_128_SHA";
        case 0xC013: return @"TLS_ECDHE_RSA_WITH_AES_128_CBC_SHA";
        case 0xC014: return @"TLS_ECDHE_RSA_WITH_AES_256_CBC_SHA";
        case 0xC023: return @"TLS_ECDHE_ECDSA_WITH_AES_128_CBC_SHA256";
        case 0xC024: return @"TLS_ECDHE_ECDSA_WITH_AES_256_CBC_SHA384";
        case 0xC027: return @"TLS_ECDHE_RSA_WITH_AES_128_CBC_SHA256";
        case 0xC028: return @"TLS_ECDHE_RSA_WITH_AES_256_CBC_SHA384";
        case 0xC02B: return @"TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256";
        case 0xC02C: return @"TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384";
        case 0xC02F: return @"TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256";
        case 0xC030: return @"TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384";
        default: return nil;
    }
}

+ (NSString *)yesNo:(BOOL)value {
    return value ? @"YES" : @"NO";
}

+ (NSString *)diagnosticReportForHost:(NSString *)host port:(NSUInteger)port {
    NSMutableString *report = [NSMutableString string];
    [report appendFormat:@"Host: %@:%lu\n", host ? host : @"(null)", (unsigned long)port];
    [report appendString:@"Device TLS stack: Apple SecureTransport\n\n"];

    SSLContextRef context = NULL;
    OSStatus status = SSLNewContext(false, &context);
    if (status != noErr || context == NULL) {
        [report appendFormat:@"SSLNewContext failed: %ld\n", (long)status];
        return report;
    }

    size_t supportedCount = 0;
    status = SSLGetNumberSupportedCiphers(context, &supportedCount);
    if (status != noErr) {
        [report appendFormat:@"SSLGetNumberSupportedCiphers failed: %ld\n", (long)status];
        SSLDisposeContext(context);
        return report;
    }

    SSLCipherSuite *supported = NULL;
    if (supportedCount > 0) {
        supported = (SSLCipherSuite *)calloc(supportedCount, sizeof(SSLCipherSuite));
    }

    size_t supportedCapacity = supportedCount;
    if (supported && supportedCount > 0) {
        status = SSLGetSupportedCiphers(context, supported, &supportedCapacity);
        if (status != noErr) {
            [report appendFormat:@"SSLGetSupportedCiphers failed: %ld\n", (long)status];
            free(supported);
            SSLDisposeContext(context);
            return report;
        }
        supportedCount = supportedCapacity;
    }

    size_t enabledCount = 0;
    SSLCipherSuite *enabled = NULL;
    OSStatus enabledStatus = SSLGetNumberEnabledCiphers(context, &enabledCount);
    if (enabledStatus == noErr && enabledCount > 0) {
        enabled = (SSLCipherSuite *)calloc(enabledCount, sizeof(SSLCipherSuite));
        size_t enabledCapacity = enabledCount;
        if (enabled) {
            enabledStatus = SSLGetEnabledCiphers(context, enabled, &enabledCapacity);
            if (enabledStatus == noErr) enabledCount = enabledCapacity;
        }
    }

    [report appendFormat:@"Supported ciphers: %lu\n", (unsigned long)supportedCount];
    if (enabledStatus == noErr) {
        [report appendFormat:@"Enabled ciphers: %lu\n", (unsigned long)enabledCount];
    } else {
        [report appendFormat:@"Enabled ciphers: query failed (%ld)\n", (long)enabledStatus];
    }

    [report appendString:@"\nCritical suites for current mail server tests:\n"];
    [report appendFormat:@"0xC009 ECDHE-ECDSA-AES128-SHA: supported %@ / enabled %@\n",
     [self yesNo:[self cipher:0xC009 isPresentInList:supported count:supportedCount]],
     [self yesNo:[self cipher:0xC009 isPresentInList:enabled count:enabledCount]]];
    [report appendFormat:@"0xC00A ECDHE-ECDSA-AES256-SHA: supported %@ / enabled %@\n",
     [self yesNo:[self cipher:0xC00A isPresentInList:supported count:supportedCount]],
     [self yesNo:[self cipher:0xC00A isPresentInList:enabled count:enabledCount]]];
    [report appendFormat:@"0xC02B ECDHE-ECDSA-AES128-GCM-SHA256: supported %@ / enabled %@\n",
     [self yesNo:[self cipher:0xC02B isPresentInList:supported count:supportedCount]],
     [self yesNo:[self cipher:0xC02B isPresentInList:enabled count:enabledCount]]];
    [report appendFormat:@"0xC02C ECDHE-ECDSA-AES256-GCM-SHA384: supported %@ / enabled %@\n",
     [self yesNo:[self cipher:0xC02C isPresentInList:supported count:supportedCount]],
     [self yesNo:[self cipher:0xC02C isPresentInList:enabled count:enabledCount]]];

    [report appendString:@"\nSupported cipher IDs:\n"];
    size_t i;
    for (i = 0; i < supportedCount; i++) {
        NSString *name = [self nameForCipher:supported[i]];
        if (name) {
            [report appendFormat:@"0x%04X %@\n", (unsigned int)supported[i], name];
        } else {
            [report appendFormat:@"0x%04X\n", (unsigned int)supported[i]];
        }
    }

    if (enabled) free(enabled);
    if (supported) free(supported);
    SSLDisposeContext(context);
    return report;
}

@end
