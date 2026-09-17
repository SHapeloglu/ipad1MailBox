#import "IMBIMAPClient.h"
#import "IMBAccount.h"
#import <CFNetwork/CFNetwork.h>

static NSString * const IMBIMAPErrorDomain = @"com.shapeloglu.ipad1mailbox.imap";

enum {
    IMBIMAPStateDisconnected = 0,
    IMBIMAPStateWaitingGreeting,
    IMBIMAPStateWaitingLogin,
    IMBIMAPStateWaitingSelect,
    IMBIMAPStateWaitingFetch
};

@implementation IMBIMAPClient

@synthesize delegate = _delegate;

- (id)init {
    self = [super init];
    if (self) {
        _state = IMBIMAPStateDisconnected;
        _receiveBuffer = [[NSMutableData alloc] init];
    }
    return self;
}

- (NSError *)errorWithCode:(NSInteger)code description:(NSString *)description {
    NSDictionary *info = [NSDictionary dictionaryWithObject:(description ? description : @"IMAP error")
                                                      forKey:NSLocalizedDescriptionKey];
    return [NSError errorWithDomain:IMBIMAPErrorDomain code:code userInfo:info];
}

- (void)resetTimeout {
    [_timeoutTimer invalidate];
    [_timeoutTimer release];
    _timeoutTimer = [[NSTimer scheduledTimerWithTimeInterval:20.0
                                                     target:self
                                                   selector:@selector(timeoutFired:)
                                                   userInfo:nil
                                                    repeats:NO] retain];
}

- (void)timeoutFired:(NSTimer *)timer {
    [self failWithError:[self errorWithCode:100 description:@"IMAP connection timed out after 20 seconds."]];
}

- (void)closeStreams {
    if (_inputStream) {
        [_inputStream setDelegate:nil];
        [_inputStream removeFromRunLoop:[NSRunLoop mainRunLoop] forMode:NSDefaultRunLoopMode];
        [_inputStream close];
        CFRelease((CFTypeRef)_inputStream);
        _inputStream = nil;
    }
    if (_outputStream) {
        [_outputStream setDelegate:nil];
        [_outputStream removeFromRunLoop:[NSRunLoop mainRunLoop] forMode:NSDefaultRunLoopMode];
        [_outputStream close];
        CFRelease((CFTypeRef)_outputStream);
        _outputStream = nil;
    }
}

- (void)cancel {
    _finished = YES;
    [_timeoutTimer invalidate];
    [_timeoutTimer release];
    _timeoutTimer = nil;
    [self closeStreams];
    _state = IMBIMAPStateDisconnected;
}

- (void)cleanupSessionObjects {
    [_account release];
    _account = nil;
    [_password release];
    _password = nil;
    [_receiveBuffer setLength:0];
}

- (void)failWithError:(NSError *)error {
    if (_finished) return;
    _finished = YES;
    [_timeoutTimer invalidate];
    [_timeoutTimer release];
    _timeoutTimer = nil;
    [self closeStreams];
    _state = IMBIMAPStateDisconnected;

    id<IMBIMAPClientDelegate> delegate = _delegate;
    if (delegate && [delegate respondsToSelector:@selector(imapClient:didFailWithError:)]) {
        [delegate imapClient:self didFailWithError:error];
    }
    [self cleanupSessionObjects];
}

- (void)finishWithMessages:(NSArray *)messages {
    if (_finished) return;
    _finished = YES;
    [_timeoutTimer invalidate];
    [_timeoutTimer release];
    _timeoutTimer = nil;

    if (_outputStream) {
        const char *logout = "A999 LOGOUT\r\n";
        [_outputStream write:(const uint8_t *)logout maxLength:strlen(logout)];
    }

    [self closeStreams];
    _state = IMBIMAPStateDisconnected;

    id<IMBIMAPClientDelegate> delegate = _delegate;
    if (delegate && [delegate respondsToSelector:@selector(imapClient:didLoadMessages:)]) {
        [delegate imapClient:self didLoadMessages:messages];
    }
    [self cleanupSessionObjects];
}

- (NSString *)quotedIMAPString:(NSString *)value {
    if (!value) return @"\"\"";
    NSMutableString *safe = [NSMutableString stringWithString:value];
    [safe replaceOccurrencesOfString:@"\\" withString:@"\\\\" options:0 range:NSMakeRange(0, [safe length])];
    [safe replaceOccurrencesOfString:@"\"" withString:@"\\\"" options:0 range:NSMakeRange(0, [safe length])];
    [safe replaceOccurrencesOfString:@"\r" withString:@"" options:0 range:NSMakeRange(0, [safe length])];
    [safe replaceOccurrencesOfString:@"\n" withString:@"" options:0 range:NSMakeRange(0, [safe length])];
    return [NSString stringWithFormat:@"\"%@\"", safe];
}

- (BOOL)sendCommand:(NSString *)command nextState:(NSInteger)state {
    if (!_outputStream || !command) return NO;

    NSData *data = [command dataUsingEncoding:NSUTF8StringEncoding];
    const uint8_t *bytes = (const uint8_t *)[data bytes];
    NSUInteger total = [data length];
    NSUInteger offset = 0;

    while (offset < total) {
        NSInteger written = [_outputStream write:bytes + offset maxLength:total - offset];
        if (written <= 0) {
            NSError *streamError = [_outputStream streamError];
            NSString *message = streamError ? [streamError localizedDescription] : @"Unable to write to IMAP server.";
            [self failWithError:[self errorWithCode:101 description:message]];
            return NO;
        }
        offset += (NSUInteger)written;
    }

    [_receiveBuffer setLength:0];
    _state = state;
    [self resetTimeout];
    return YES;
}

- (void)fetchLatestHeadersForAccount:(IMBAccount *)account password:(NSString *)password {
    [self cancel];
    [self cleanupSessionObjects];

    if (!account || [account.imapHost length] == 0 || account.imapPort == 0) {
        _finished = NO;
        [self failWithError:[self errorWithCode:102 description:@"IMAP server or port is missing."]];
        return;
    }
    if ([account.username length] == 0 || [password length] == 0) {
        _finished = NO;
        [self failWithError:[self errorWithCode:103 description:@"Username or password is missing."]];
        return;
    }

    _finished = NO;
    _account = [account retain];
    _password = [password copy];
    _messageCount = 0;
    [_receiveBuffer setLength:0];

    CFReadStreamRef readStream = NULL;
    CFWriteStreamRef writeStream = NULL;
    CFStreamCreatePairWithSocketToHost(kCFAllocatorDefault,
                                       (CFStringRef)account.imapHost,
                                       (UInt32)account.imapPort,
                                       &readStream,
                                       &writeStream);

    if (!readStream || !writeStream) {
        if (readStream) CFRelease(readStream);
        if (writeStream) CFRelease(writeStream);
        [self failWithError:[self errorWithCode:104 description:@"Unable to create IMAP network streams."]];
        return;
    }

    _inputStream = (NSInputStream *)readStream;
    _outputStream = (NSOutputStream *)writeStream;

    if (account.imapUseSSL) {
        NSDictionary *sslSettings = [NSDictionary dictionaryWithObjectsAndKeys:
                                     (id)kCFStreamSocketSecurityLevelNegotiatedSSL, (id)kCFStreamSSLLevel,
                                     account.imapHost, (id)kCFStreamSSLPeerName,
                                     nil];
        CFReadStreamSetProperty(readStream, kCFStreamPropertySSLSettings, (CFTypeRef)sslSettings);
        CFWriteStreamSetProperty(writeStream, kCFStreamPropertySSLSettings, (CFTypeRef)sslSettings);
    }

    [_inputStream setDelegate:self];
    [_outputStream setDelegate:self];
    [_inputStream scheduleInRunLoop:[NSRunLoop mainRunLoop] forMode:NSDefaultRunLoopMode];
    [_outputStream scheduleInRunLoop:[NSRunLoop mainRunLoop] forMode:NSDefaultRunLoopMode];

    _state = IMBIMAPStateWaitingGreeting;
    [_inputStream open];
    [_outputStream open];
    [self resetTimeout];
}

- (NSString *)responseString {
    if ([_receiveBuffer length] == 0) return @"";
    NSString *text = [[[NSString alloc] initWithData:_receiveBuffer encoding:NSUTF8StringEncoding] autorelease];
    if (!text) {
        text = [[[NSString alloc] initWithData:_receiveBuffer encoding:NSISOLatin1StringEncoding] autorelease];
    }
    return text ? text : @"";
}

- (NSString *)firstCompleteLineInResponse:(NSString *)response {
    NSRange end = [response rangeOfString:@"\r\n"];
    if (end.location == NSNotFound) return nil;
    return [response substringToIndex:end.location];
}

- (NSString *)completeTaggedLineForTag:(NSString *)tag response:(NSString *)response {
    NSArray *lines = [response componentsSeparatedByString:@"\r\n"];
    if ([lines count] < 2) return nil;

    NSString *prefix = [NSString stringWithFormat:@"%@ ", tag];
    NSUInteger lastComplete = [lines count] - 1;
    NSUInteger i;
    for (i = 0; i < lastComplete; i++) {
        NSString *line = [lines objectAtIndex:i];
        if ([line hasPrefix:prefix]) return line;
    }
    return nil;
}

- (BOOL)taggedLineIsOK:(NSString *)line tag:(NSString *)tag {
    NSString *prefix = [NSString stringWithFormat:@"%@ OK", tag];
    return [line hasPrefix:prefix];
}

- (NSString *)messageForTaggedFailure:(NSString *)line fallback:(NSString *)fallback {
    if ([line length] > 0) return line;
    return fallback;
}

- (NSUInteger)existsCountFromSelectResponse:(NSString *)response {
    NSArray *lines = [response componentsSeparatedByString:@"\r\n"];
    for (NSString *line in lines) {
        if (![line hasPrefix:@"* "] || [line rangeOfString:@" EXISTS"].location == NSNotFound) continue;
        NSArray *parts = [line componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        NSMutableArray *clean = [NSMutableArray array];
        for (NSString *part in parts) {
            if ([part length] > 0) [clean addObject:part];
        }
        if ([clean count] >= 3) {
            return (NSUInteger)[[clean objectAtIndex:1] integerValue];
        }
    }
    return 0;
}

- (NSString *)trimmedHeaderValue:(NSString *)value {
    return [value stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

- (NSArray *)messagesFromFetchResponse:(NSString *)response {
    NSArray *lines = [response componentsSeparatedByString:@"\r\n"];
    NSMutableArray *messages = [NSMutableArray array];
    NSMutableDictionary *current = nil;
    NSString *lastHeader = nil;

    for (NSString *line in lines) {
        if ([line hasPrefix:@"* "] && [line rangeOfString:@" FETCH ("].location != NSNotFound) {
            if (current) {
                [messages addObject:current];
                current = nil;
            }
            current = [NSMutableDictionary dictionary];

            NSArray *parts = [line componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
            NSMutableArray *clean = [NSMutableArray array];
            for (NSString *part in parts) if ([part length] > 0) [clean addObject:part];
            if ([clean count] >= 2) [current setObject:[clean objectAtIndex:1] forKey:@"sequence"];

            NSRange uidRange = [line rangeOfString:@"UID "];
            if (uidRange.location != NSNotFound) {
                NSString *tail = [line substringFromIndex:uidRange.location + uidRange.length];
                NSScanner *scanner = [NSScanner scannerWithString:tail];
                NSInteger uidValue = 0;
                if ([scanner scanInteger:&uidValue]) {
                    [current setObject:[NSString stringWithFormat:@"%ld", (long)uidValue] forKey:@"uid"];
                }
            }
            lastHeader = nil;
            continue;
        }

        if (!current) continue;
        if ([line isEqualToString:@")"] || [line hasPrefix:@"A003 "]) {
            if ([current count] > 0) [messages addObject:current];
            current = nil;
            lastHeader = nil;
            continue;
        }

        if (([line hasPrefix:@" "] || [line hasPrefix:@"\t"]) && lastHeader) {
            NSString *existing = [current objectForKey:lastHeader];
            NSString *continued = [self trimmedHeaderValue:line];
            if ([continued length] > 0) {
                NSString *combined = existing ? [NSString stringWithFormat:@"%@ %@", existing, continued] : continued;
                [current setObject:combined forKey:lastHeader];
            }
            continue;
        }

        NSRange colon = [line rangeOfString:@":"];
        if (colon.location == NSNotFound) continue;
        NSString *name = [[line substringToIndex:colon.location] lowercaseString];
        NSString *value = [self trimmedHeaderValue:[line substringFromIndex:colon.location + 1]];

        if ([name isEqualToString:@"from"]) {
            [current setObject:(value ? value : @"") forKey:@"from"];
            lastHeader = @"from";
        } else if ([name isEqualToString:@"subject"]) {
            [current setObject:(value ? value : @"") forKey:@"subject"];
            lastHeader = @"subject";
        } else if ([name isEqualToString:@"date"]) {
            [current setObject:(value ? value : @"") forKey:@"date"];
            lastHeader = @"date";
        } else {
            lastHeader = nil;
        }
    }

    if (current && [current count] > 0) [messages addObject:current];

    NSMutableArray *reversed = [NSMutableArray arrayWithCapacity:[messages count]];
    NSInteger index;
    for (index = (NSInteger)[messages count] - 1; index >= 0; index--) {
        [reversed addObject:[messages objectAtIndex:(NSUInteger)index]];
    }
    return reversed;
}

- (void)processReceivedData {
    NSString *response = [self responseString];
    if ([response length] == 0) return;

    if (_state == IMBIMAPStateWaitingGreeting) {
        NSString *line = [self firstCompleteLineInResponse:response];
        if (!line) return;

        if ([line hasPrefix:@"* PREAUTH"]) {
            [self sendCommand:@"A002 SELECT \"INBOX\"\r\n" nextState:IMBIMAPStateWaitingSelect];
            return;
        }
        if (![line hasPrefix:@"* OK"]) {
            [self failWithError:[self errorWithCode:105 description:[NSString stringWithFormat:@"Unexpected IMAP greeting: %@", line]]];
            return;
        }

        NSString *login = [NSString stringWithFormat:@"A001 LOGIN %@ %@\r\n",
                           [self quotedIMAPString:_account.username],
                           [self quotedIMAPString:_password]];
        [self sendCommand:login nextState:IMBIMAPStateWaitingLogin];
        return;
    }

    if (_state == IMBIMAPStateWaitingLogin) {
        NSString *line = [self completeTaggedLineForTag:@"A001" response:response];
        if (!line) return;
        if (![self taggedLineIsOK:line tag:@"A001"]) {
            [self failWithError:[self errorWithCode:106 description:[self messageForTaggedFailure:line fallback:@"IMAP login failed."]]];
            return;
        }
        [self sendCommand:@"A002 SELECT \"INBOX\"\r\n" nextState:IMBIMAPStateWaitingSelect];
        return;
    }

    if (_state == IMBIMAPStateWaitingSelect) {
        NSString *line = [self completeTaggedLineForTag:@"A002" response:response];
        if (!line) return;
        if (![self taggedLineIsOK:line tag:@"A002"]) {
            [self failWithError:[self errorWithCode:107 description:[self messageForTaggedFailure:line fallback:@"Unable to open INBOX."]]];
            return;
        }

        _messageCount = [self existsCountFromSelectResponse:response];
        if (_messageCount == 0) {
            [self finishWithMessages:[NSArray array]];
            return;
        }

        NSUInteger first = (_messageCount > 25) ? (_messageCount - 24) : 1;
        NSString *fetch = [NSString stringWithFormat:@"A003 FETCH %lu:%lu (UID BODY.PEEK[HEADER.FIELDS (FROM SUBJECT DATE)])\r\n",
                           (unsigned long)first,
                           (unsigned long)_messageCount];
        [self sendCommand:fetch nextState:IMBIMAPStateWaitingFetch];
        return;
    }

    if (_state == IMBIMAPStateWaitingFetch) {
        NSString *line = [self completeTaggedLineForTag:@"A003" response:response];
        if (!line) return;
        if (![self taggedLineIsOK:line tag:@"A003"]) {
            [self failWithError:[self errorWithCode:108 description:[self messageForTaggedFailure:line fallback:@"Unable to fetch message headers."]]];
            return;
        }

        NSArray *messages = [self messagesFromFetchResponse:response];
        [self finishWithMessages:messages];
    }
}

- (void)stream:(NSStream *)aStream handleEvent:(NSStreamEvent)eventCode {
    if (_finished) return;

    switch (eventCode) {
        case NSStreamEventOpenCompleted:
            [self resetTimeout];
            break;

        case NSStreamEventHasBytesAvailable: {
            uint8_t buffer[2048];
            NSInteger readCount = [(NSInputStream *)aStream read:buffer maxLength:sizeof(buffer)];
            if (readCount > 0) {
                [_receiveBuffer appendBytes:buffer length:(NSUInteger)readCount];
                [self resetTimeout];
                [self processReceivedData];
            } else if (readCount < 0) {
                NSError *streamError = [aStream streamError];
                NSString *message = streamError ? [streamError localizedDescription] : @"IMAP read failed.";
                [self failWithError:[self errorWithCode:109 description:message]];
            }
            break;
        }

        case NSStreamEventErrorOccurred: {
            NSError *streamError = [aStream streamError];
            NSString *message = streamError ? [streamError localizedDescription] : @"IMAP network or SSL/TLS error.";
            if (_account) {
                message = [NSString stringWithFormat:@"%@\n\nServer: %@:%lu%@",
                           message,
                           _account.imapHost,
                           (unsigned long)_account.imapPort,
                           _account.imapUseSSL ? @" (SSL/TLS)" : @""];
            }
            [self failWithError:[self errorWithCode:110 description:message]];
            break;
        }

        case NSStreamEventEndEncountered:
            [self failWithError:[self errorWithCode:111 description:@"IMAP server closed the connection unexpectedly."]];
            break;

        default:
            break;
    }
}

- (void)dealloc {
    _delegate = nil;
    [self cancel];
    [self cleanupSessionObjects];
    [_receiveBuffer release];
    [super dealloc];
}

@end
