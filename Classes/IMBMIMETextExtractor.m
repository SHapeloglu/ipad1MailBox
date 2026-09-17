#import "IMBMIMETextExtractor.h"
#import <CoreFoundation/CoreFoundation.h>

static int IMBMIMEHexValue(unichar c) {
    if (c >= '0' && c <= '9') return (int)(c - '0');
    if (c >= 'A' && c <= 'F') return 10 + (int)(c - 'A');
    if (c >= 'a' && c <= 'f') return 10 + (int)(c - 'a');
    return -1;
}

static int IMBMIMEBase64Value(unichar c) {
    if (c >= 'A' && c <= 'Z') return (int)(c - 'A');
    if (c >= 'a' && c <= 'z') return 26 + (int)(c - 'a');
    if (c >= '0' && c <= '9') return 52 + (int)(c - '0');
    if (c == '+') return 62;
    if (c == '/') return 63;
    return -1;
}

static NSData *IMBMIMEDecodeBase64(NSString *text) {
    NSMutableData *data = [NSMutableData data];
    unsigned int accumulator = 0;
    int bitCount = 0;
    NSUInteger i;

    for (i = 0; i < [text length]; i++) {
        unichar c = [text characterAtIndex:i];
        if (c == '=') break;

        int value = IMBMIMEBase64Value(c);
        if (value < 0) {
            if ([[NSCharacterSet whitespaceAndNewlineCharacterSet] characterIsMember:c]) continue;
            return nil;
        }

        accumulator = (accumulator << 6) | (unsigned int)value;
        bitCount += 6;
        if (bitCount >= 8) {
            bitCount -= 8;
            uint8_t byte = (uint8_t)((accumulator >> bitCount) & 0xFFU);
            [data appendBytes:&byte length:1];
            if (bitCount == 0) accumulator = 0;
            else accumulator &= ((1U << bitCount) - 1U);
        }
    }
    return data;
}

static NSData *IMBMIMEDecodeQuotedPrintable(NSString *text) {
    NSMutableData *data = [NSMutableData data];
    NSUInteger i = 0;
    NSUInteger length = [text length];

    while (i < length) {
        unichar c = [text characterAtIndex:i];
        if (c == '=') {
            if (i + 1 < length && [text characterAtIndex:i + 1] == '\n') {
                i += 2;
                continue;
            }
            if (i + 2 < length && [text characterAtIndex:i + 1] == '\r' && [text characterAtIndex:i + 2] == '\n') {
                i += 3;
                continue;
            }
            if (i + 2 < length) {
                int high = IMBMIMEHexValue([text characterAtIndex:i + 1]);
                int low = IMBMIMEHexValue([text characterAtIndex:i + 2]);
                if (high >= 0 && low >= 0) {
                    uint8_t byte = (uint8_t)((high << 4) | low);
                    [data appendBytes:&byte length:1];
                    i += 3;
                    continue;
                }
            }
        }

        if (c <= 0xFF) {
            uint8_t byte = (uint8_t)c;
            [data appendBytes:&byte length:1];
        }
        i++;
    }
    return data;
}

static NSStringEncoding IMBMIMEEncodingForCharset(NSString *charset) {
    if ([charset length] == 0) return NSUTF8StringEncoding;
    NSString *normalized = [[charset stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] lowercaseString];

    if ([normalized isEqualToString:@"utf-8"] || [normalized isEqualToString:@"utf8"]) return NSUTF8StringEncoding;
    if ([normalized isEqualToString:@"us-ascii"] || [normalized isEqualToString:@"ascii"]) return NSASCIIStringEncoding;
    if ([normalized isEqualToString:@"iso-8859-1"] || [normalized isEqualToString:@"latin1"] || [normalized isEqualToString:@"latin-1"]) return NSISOLatin1StringEncoding;

    CFStringEncoding cfEncoding = CFStringConvertIANACharSetNameToEncoding((CFStringRef)normalized);
    if (cfEncoding == kCFStringEncodingInvalidId) return NSUTF8StringEncoding;
    return CFStringConvertEncodingToNSStringEncoding(cfEncoding);
}

static NSString *IMBMIMEStringFromData(NSData *data, NSString *charset) {
    if (!data) return nil;
    NSStringEncoding encoding = IMBMIMEEncodingForCharset(charset);
    NSString *value = [[[NSString alloc] initWithData:data encoding:encoding] autorelease];
    if (value) return value;

    value = [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] autorelease];
    if (value) return value;
    return [[[NSString alloc] initWithData:data encoding:NSISOLatin1StringEncoding] autorelease];
}

static NSDictionary *IMBMIMEParseHeaders(NSString *headerText) {
    NSMutableDictionary *headers = [NSMutableDictionary dictionary];
    NSArray *lines = [headerText componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
    NSString *currentName = nil;
    NSMutableString *currentValue = nil;

    for (NSString *rawLine in lines) {
        NSString *line = [rawLine stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"\r"]];
        if (([line hasPrefix:@" "] || [line hasPrefix:@"\t"]) && currentName) {
            NSString *continuation = [line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
            if ([continuation length] > 0) {
                [currentValue appendString:@" "];
                [currentValue appendString:continuation];
            }
            continue;
        }

        if (currentName) {
            [headers setObject:[[currentValue copy] autorelease] forKey:currentName];
            currentName = nil;
            currentValue = nil;
        }

        NSRange colon = [line rangeOfString:@":"];
        if (colon.location == NSNotFound) continue;
        currentName = [[[line substringToIndex:colon.location] lowercaseString] copy];
        NSString *value = [[line substringFromIndex:colon.location + 1] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        currentValue = [NSMutableString stringWithString:value ? value : @""];
        [currentName autorelease];
    }

    if (currentName) {
        [headers setObject:[[currentValue copy] autorelease] forKey:currentName];
    }
    return headers;
}

static NSString *IMBMIMEParameter(NSString *headerValue, NSString *parameterName) {
    if ([headerValue length] == 0) return nil;
    NSArray *parts = [headerValue componentsSeparatedByString:@";"];
    NSUInteger i;
    for (i = 1; i < [parts count]; i++) {
        NSString *part = [[parts objectAtIndex:i] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        NSRange equals = [part rangeOfString:@"="];
        if (equals.location == NSNotFound) continue;
        NSString *name = [[[part substringToIndex:equals.location] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] lowercaseString];
        if (![name isEqualToString:[parameterName lowercaseString]]) continue;
        NSString *value = [[part substringFromIndex:equals.location + 1] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if ([value length] >= 2 && [value hasPrefix:@"\""] && [value hasSuffix:@"\""]) {
            value = [value substringWithRange:NSMakeRange(1, [value length] - 2)];
        }
        return value;
    }
    return nil;
}

static NSString *IMBMIMEMediaType(NSString *contentType) {
    if ([contentType length] == 0) return @"text/plain";
    NSRange semicolon = [contentType rangeOfString:@";"];
    NSString *type = (semicolon.location == NSNotFound) ? contentType : [contentType substringToIndex:semicolon.location];
    return [[type stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] lowercaseString];
}

static NSRange IMBMIMEHeaderBodySeparator(NSString *entityText) {
    NSRange separator = [entityText rangeOfString:@"\r\n\r\n"];
    if (separator.location != NSNotFound) return NSMakeRange(separator.location, 4);
    separator = [entityText rangeOfString:@"\n\n"];
    if (separator.location != NSNotFound) return NSMakeRange(separator.location, 2);
    return NSMakeRange(NSNotFound, 0);
}

static NSString *IMBMIMEExtractEntity(NSData *entityData, NSUInteger depth) {
    if (!entityData || [entityData length] == 0 || depth > 6) return nil;

    NSString *entityText = [[[NSString alloc] initWithData:entityData encoding:NSISOLatin1StringEncoding] autorelease];
    if (!entityText) return nil;

    NSRange separator = IMBMIMEHeaderBodySeparator(entityText);
    NSString *headerText = @"";
    NSData *bodyData = entityData;
    if (separator.location != NSNotFound) {
        headerText = [entityText substringToIndex:separator.location];
        NSUInteger bodyOffset = separator.location + separator.length;
        if (bodyOffset <= [entityData length]) {
            bodyData = [entityData subdataWithRange:NSMakeRange(bodyOffset, [entityData length] - bodyOffset)];
        }
    }

    NSDictionary *headers = IMBMIMEParseHeaders(headerText);
    NSString *contentType = [headers objectForKey:@"content-type"];
    NSString *mediaType = IMBMIMEMediaType(contentType);
    NSString *disposition = [[[headers objectForKey:@"content-disposition"] lowercaseString] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

    if ([disposition hasPrefix:@"attachment"]) return nil;

    if ([mediaType hasPrefix:@"multipart/"]) {
        NSString *boundary = IMBMIMEParameter(contentType, @"boundary");
        if ([boundary length] == 0) return nil;

        NSString *bodyText = [[[NSString alloc] initWithData:bodyData encoding:NSISOLatin1StringEncoding] autorelease];
        if (!bodyText) return nil;
        NSString *delimiter = [NSString stringWithFormat:@"--%@", boundary];
        NSArray *parts = [bodyText componentsSeparatedByString:delimiter];
        NSUInteger i;
        for (i = 1; i < [parts count]; i++) {
            NSString *part = [parts objectAtIndex:i];
            if ([part hasPrefix:@"--"]) break;
            while ([part hasPrefix:@"\r\n"]) part = [part substringFromIndex:2];
            while ([part hasPrefix:@"\n"]) part = [part substringFromIndex:1];
            if ([part length] == 0) continue;

            NSData *partData = [part dataUsingEncoding:NSISOLatin1StringEncoding allowLossyConversion:YES];
            NSString *plain = IMBMIMEExtractEntity(partData, depth + 1);
            if ([plain length] > 0) return plain;
        }
        return nil;
    }

    if ([mediaType isEqualToString:@"message/rfc822"]) {
        return IMBMIMEExtractEntity(bodyData, depth + 1);
    }

    if (![mediaType isEqualToString:@"text/plain"]) return nil;

    NSString *bodyText = [[[NSString alloc] initWithData:bodyData encoding:NSISOLatin1StringEncoding] autorelease];
    if (!bodyText) return nil;

    NSString *transferEncoding = [[[headers objectForKey:@"content-transfer-encoding"] lowercaseString] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSData *decodedData = nil;
    if ([transferEncoding isEqualToString:@"base64"]) {
        decodedData = IMBMIMEDecodeBase64(bodyText);
    } else if ([transferEncoding isEqualToString:@"quoted-printable"]) {
        decodedData = IMBMIMEDecodeQuotedPrintable(bodyText);
    } else {
        decodedData = [bodyText dataUsingEncoding:NSISOLatin1StringEncoding allowLossyConversion:YES];
    }

    NSString *charset = IMBMIMEParameter(contentType, @"charset");
    NSString *plain = IMBMIMEStringFromData(decodedData, charset);
    if (!plain) return nil;

    plain = [plain stringByReplacingOccurrencesOfString:@"\r\n" withString:@"\n"];
    plain = [plain stringByReplacingOccurrencesOfString:@"\r" withString:@"\n"];
    return [plain stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

@implementation IMBMIMETextExtractor

+ (NSString *)plainTextFromMessageData:(NSData *)messageData {
    return IMBMIMEExtractEntity(messageData, 0);
}

@end
