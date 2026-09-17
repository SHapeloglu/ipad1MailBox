#import "IMBRFC2047Decoder.h"
#import <CoreFoundation/CoreFoundation.h>

static int IMBHexValue(unichar c) {
    if (c >= '0' && c <= '9') return (int)(c - '0');
    if (c >= 'A' && c <= 'F') return 10 + (int)(c - 'A');
    if (c >= 'a' && c <= 'f') return 10 + (int)(c - 'a');
    return -1;
}

static int IMBBase64Value(unichar c) {
    if (c >= 'A' && c <= 'Z') return (int)(c - 'A');
    if (c >= 'a' && c <= 'z') return 26 + (int)(c - 'a');
    if (c >= '0' && c <= '9') return 52 + (int)(c - '0');
    if (c == '+') return 62;
    if (c == '/') return 63;
    return -1;
}

static NSData *IMBDecodeQEncodedWord(NSString *text) {
    NSMutableData *data = [NSMutableData data];
    NSUInteger length = [text length];
    NSUInteger i = 0;

    while (i < length) {
        unichar c = [text characterAtIndex:i];

        if (c == '_') {
            uint8_t space = ' ';
            [data appendBytes:&space length:1];
            i++;
            continue;
        }

        if (c == '=' && i + 2 < length) {
            int high = IMBHexValue([text characterAtIndex:i + 1]);
            int low = IMBHexValue([text characterAtIndex:i + 2]);
            if (high >= 0 && low >= 0) {
                uint8_t byte = (uint8_t)((high << 4) | low);
                [data appendBytes:&byte length:1];
                i += 3;
                continue;
            }
        }

        if (c <= 0x7F) {
            uint8_t byte = (uint8_t)c;
            [data appendBytes:&byte length:1];
        } else {
            NSString *single = [NSString stringWithCharacters:&c length:1];
            NSData *utf8 = [single dataUsingEncoding:NSUTF8StringEncoding];
            if (utf8) [data appendData:utf8];
        }
        i++;
    }

    return data;
}

static NSData *IMBDecodeBase64EncodedWord(NSString *text) {
    NSMutableData *data = [NSMutableData data];
    int accumulator = 0;
    int bits = -8;
    NSUInteger length = [text length];
    NSUInteger i;

    for (i = 0; i < length; i++) {
        unichar c = [text characterAtIndex:i];
        if (c == '=') break;

        int value = IMBBase64Value(c);
        if (value < 0) {
            if ([[NSCharacterSet whitespaceAndNewlineCharacterSet] characterIsMember:c]) continue;
            return nil;
        }

        accumulator = (accumulator << 6) | value;
        bits += 6;
        if (bits >= 0) {
            uint8_t byte = (uint8_t)((accumulator >> bits) & 0xFF);
            [data appendBytes:&byte length:1];
            bits -= 8;
        }
    }

    return data;
}

static NSStringEncoding IMBStringEncodingForCharset(NSString *charset) {
    if ([charset length] == 0) return 0;

    NSString *normalized = [[charset stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] lowercaseString];
    NSRange languageSeparator = [normalized rangeOfString:@"*"];
    if (languageSeparator.location != NSNotFound) {
        normalized = [normalized substringToIndex:languageSeparator.location];
    }

    if ([normalized isEqualToString:@"utf-8"] || [normalized isEqualToString:@"utf8"]) {
        return NSUTF8StringEncoding;
    }
    if ([normalized isEqualToString:@"us-ascii"] || [normalized isEqualToString:@"ascii"]) {
        return NSASCIIStringEncoding;
    }
    if ([normalized isEqualToString:@"iso-8859-1"] || [normalized isEqualToString:@"latin1"] || [normalized isEqualToString:@"latin-1"]) {
        return NSISOLatin1StringEncoding;
    }

    CFStringEncoding cfEncoding = CFStringConvertIANACharSetNameToEncoding((CFStringRef)normalized);
    if (cfEncoding == kCFStringEncodingInvalidId) return 0;
    return CFStringConvertEncodingToNSStringEncoding(cfEncoding);
}

static NSString *IMBStringFromDecodedData(NSData *data, NSString *charset) {
    if (!data) return nil;

    NSStringEncoding encoding = IMBStringEncodingForCharset(charset);
    if (encoding != 0) {
        NSString *decoded = [[[NSString alloc] initWithData:data encoding:encoding] autorelease];
        if (decoded) return decoded;
    }

    NSString *utf8 = [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] autorelease];
    if (utf8) return utf8;

    return [[[NSString alloc] initWithData:data encoding:NSISOLatin1StringEncoding] autorelease];
}

static BOOL IMBParseEncodedWord(NSString *value,
                                NSUInteger start,
                                NSString **decodedValue,
                                NSUInteger *endIndex) {
    NSUInteger length = [value length];
    if (start + 4 >= length) return NO;
    if ([value characterAtIndex:start] != '=' || [value characterAtIndex:start + 1] != '?') return NO;

    NSRange searchRange = NSMakeRange(start + 2, length - (start + 2));
    NSRange firstQuestion = [value rangeOfString:@"?" options:0 range:searchRange];
    if (firstQuestion.location == NSNotFound || firstQuestion.location == start + 2) return NO;

    NSUInteger encodingStart = firstQuestion.location + 1;
    if (encodingStart >= length) return NO;
    NSRange secondSearch = NSMakeRange(encodingStart, length - encodingStart);
    NSRange secondQuestion = [value rangeOfString:@"?" options:0 range:secondSearch];
    if (secondQuestion.location == NSNotFound || secondQuestion.location == encodingStart) return NO;

    NSUInteger textStart = secondQuestion.location + 1;
    if (textStart >= length) return NO;
    NSRange endSearch = NSMakeRange(textStart, length - textStart);
    NSRange terminator = [value rangeOfString:@"?=" options:0 range:endSearch];
    if (terminator.location == NSNotFound) return NO;

    NSString *charset = [value substringWithRange:NSMakeRange(start + 2, firstQuestion.location - (start + 2))];
    NSString *encodingToken = [value substringWithRange:NSMakeRange(encodingStart, secondQuestion.location - encodingStart)];
    NSString *encodedText = [value substringWithRange:NSMakeRange(textStart, terminator.location - textStart)];

    NSData *decodedData = nil;
    if ([encodingToken caseInsensitiveCompare:@"Q"] == NSOrderedSame) {
        decodedData = IMBDecodeQEncodedWord(encodedText);
    } else if ([encodingToken caseInsensitiveCompare:@"B"] == NSOrderedSame) {
        decodedData = IMBDecodeBase64EncodedWord(encodedText);
    } else {
        return NO;
    }

    NSString *decoded = IMBStringFromDecodedData(decodedData, charset);
    if (!decoded) return NO;

    if (decodedValue) *decodedValue = decoded;
    if (endIndex) *endIndex = terminator.location + 2;
    return YES;
}

@implementation IMBRFC2047Decoder

+ (NSString *)decodeHeaderValue:(NSString *)value {
    if ([value length] == 0 || [value rangeOfString:@"=?"].location == NSNotFound) return value;

    NSMutableString *result = [NSMutableString string];
    NSUInteger cursor = 0;
    NSUInteger length = [value length];
    BOOL previousWasEncodedWord = NO;

    while (cursor < length) {
        NSRange remaining = NSMakeRange(cursor, length - cursor);
        NSRange marker = [value rangeOfString:@"=?" options:0 range:remaining];
        if (marker.location == NSNotFound) {
            [result appendString:[value substringFromIndex:cursor]];
            break;
        }

        NSString *decoded = nil;
        NSUInteger endIndex = 0;
        if (IMBParseEncodedWord(value, marker.location, &decoded, &endIndex)) {
            NSString *between = [value substringWithRange:NSMakeRange(cursor, marker.location - cursor)];
            NSString *trimmedBetween = [between stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

            if (!(previousWasEncodedWord && [trimmedBetween length] == 0)) {
                [result appendString:between];
            }
            [result appendString:decoded];
            previousWasEncodedWord = YES;
            cursor = endIndex;
            continue;
        }

        [result appendString:[value substringWithRange:NSMakeRange(cursor, marker.location - cursor + 1)]];
        cursor = marker.location + 1;
        previousWasEncodedWord = NO;
    }

    return result;
}

@end
