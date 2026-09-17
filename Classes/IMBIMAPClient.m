#import "IMBIMAPClient.h"
#import "IMBAccount.h"
#import "IMBMBEDTLSTransport.h"
#import "IMBMIMETextExtractor.h"

static NSString * const IMBIMAPErrorDomain = @"com.shapeloglu.ipad1mailbox.imap";
static const NSUInteger IMBIMAPMaximumResponseBytes = 512 * 1024;
static const NSUInteger IMBIMAPBodyFetchLimit = 256 * 1024;
static const NSTimeInterval IMBIMAPCommandTimeout = 20.0;

@implementation IMBIMAPClient

@synthesize delegate = _delegate;

- (id)init {
    self = [super init];
    if (self) {
        _generation = 1;
    }
    return self;
}

- (NSError *)errorWithCode:(NSInteger)code description:(NSString *)description {
    NSDictionary *info = [NSDictionary dictionaryWithObject:(description ? description : @"IMAP error")
                                                      forKey:NSLocalizedDescriptionKey];
    return [NSError errorWithDomain:IMBIMAPErrorDomain code:code userInfo:info];
}

- (BOOL)isOperationCurrent:(NSUInteger)token {
    @synchronized(self) {
        return token == _generation;
    }
}

- (void)setActiveTransport:(IMBMBEDTLSTransport *)transport forToken:(NSUInteger)token {
    @synchronized(self) {
        if (token != _generation) return;
        if (_activeTransport == transport) return;
        [_activeTransport release];
        _activeTransport = [transport retain];
    }
}

- (void)clearActiveTransportIfMatches:(IMBMBEDTLSTransport *)transport {
    @synchronized(self) {
        if (_activeTransport == transport) {
            [_activeTransport release];
            _activeTransport = nil;
        }
    }
}

- (void)cancel {
    IMBMBEDTLSTransport *transport = nil;
    @synchronized(self) {
        _generation++;
        transport = [_activeTransport retain];
    }

    if (transport) {
        [transport cancel];
        [transport release];
    }
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

- (NSString *)stringFromData:(NSData *)data {
    if ([data length] == 0) return @"";
    NSString *text = [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] autorelease];
    if (!text) {
        text = [[[NSString alloc] initWithData:data encoding:NSISOLatin1StringEncoding] autorelease];
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

- (NSError *)wrappedTransportError:(NSError *)transportError account:(IMBAccount *)account code:(NSInteger)code {
    NSString *detail = transportError ? [transportError localizedDescription] : @"TLS transport failed.";
    NSString *message = [NSString stringWithFormat:@"%@\n\nServer: %@:%lu (Mbed TLS)",
                         detail,
                         account.imapHost,
                         (unsigned long)account.imapPort];
    return [self errorWithCode:code description:message];
}

- (BOOL)sendCommand:(NSString *)command
          transport:(IMBMBEDTLSTransport *)transport
              token:(NSUInteger)token
              error:(NSError **)error {
    if (![self isOperationCurrent:token]) {
        if (error) *error = [self errorWithCode:120 description:@"IMAP operation was cancelled."];
        return NO;
    }

    NSData *data = [command dataUsingEncoding:NSUTF8StringEncoding];
    NSError *transportError = nil;
    if (![transport writeData:data timeout:IMBIMAPCommandTimeout error:&transportError]) {
        if (error) *error = transportError;
        return NO;
    }
    return YES;
}

- (NSData *)readResponseDataFromTransport:(IMBMBEDTLSTransport *)transport
                                      tag:(NSString *)tag
                                 greeting:(BOOL)greeting
                                    token:(NSUInteger)token
                                    error:(NSError **)error {
    NSMutableData *buffer = [NSMutableData data];
    NSTimeInterval deadline = [NSDate timeIntervalSinceReferenceDate] + IMBIMAPCommandTimeout;

    for (;;) {
        if (![self isOperationCurrent:token]) {
            if (error) *error = [self errorWithCode:120 description:@"IMAP operation was cancelled."];
            return nil;
        }

        NSTimeInterval remaining = deadline - [NSDate timeIntervalSinceReferenceDate];
        if (remaining <= 0.0) {
            if (error) *error = [self errorWithCode:121 description:@"IMAP command timed out after 20 seconds."];
            return nil;
        }

        uint8_t bytes[4096];
        NSError *transportError = nil;
        NSInteger readCount = [transport readBytes:bytes
                                         maxLength:sizeof(bytes)
                                           timeout:remaining
                                             error:&transportError];
        if (readCount < 0) {
            if (error) *error = transportError;
            return nil;
        }
        if (readCount == 0) {
            if (error) *error = [self errorWithCode:122 description:@"IMAP server closed the TLS connection unexpectedly."];
            return nil;
        }

        [buffer appendBytes:bytes length:(NSUInteger)readCount];
        if ([buffer length] > IMBIMAPMaximumResponseBytes) {
            if (error) *error = [self errorWithCode:123 description:@"IMAP response exceeded the 512 KB safety limit."];
            return nil;
        }

        NSString *response = [self stringFromData:buffer];
        if (greeting) {
            if ([self firstCompleteLineInResponse:response]) return [NSData dataWithData:buffer];
        } else if ([tag length] > 0) {
            if ([self completeTaggedLineForTag:tag response:response]) return [NSData dataWithData:buffer];
        }
    }
}

- (NSString *)readResponseFromTransport:(IMBMBEDTLSTransport *)transport
                                    tag:(NSString *)tag
                               greeting:(BOOL)greeting
                                  token:(NSUInteger)token
                                  error:(NSError **)error {
    NSData *data = [self readResponseDataFromTransport:transport
                                                   tag:tag
                                              greeting:greeting
                                                 token:token
                                                 error:error];
    return data ? [self stringFromData:data] : nil;
}

- (NSData *)literalPayloadFromFetchData:(NSData *)responseData {
    const uint8_t *bytes = (const uint8_t *)[responseData bytes];
    NSUInteger length = [responseData length];
    NSUInteger i;

    for (i = 0; i + 4 < length; i++) {
        if (bytes[i] != '{') continue;
        NSUInteger j = i + 1;
        NSUInteger literalLength = 0;
        BOOL hasDigit = NO;
        while (j < length && bytes[j] >= '0' && bytes[j] <= '9') {
            hasDigit = YES;
            literalLength = literalLength * 10 + (NSUInteger)(bytes[j] - '0');
            j++;
        }
        if (!hasDigit || j + 2 >= length || bytes[j] != '}' || bytes[j + 1] != '\r' || bytes[j + 2] != '\n') continue;

        NSUInteger start = j + 3;
        if (start <= length && literalLength <= length - start) {
            return [responseData subdataWithRange:NSMakeRange(start, literalLength)];
        }
    }
    return nil;
}

- (BOOL)openInboxForAccount:(IMBAccount *)account
                   password:(NSString *)password
                  transport:(IMBMBEDTLSTransport *)transport
                      token:(NSUInteger)token
             selectResponse:(NSString **)selectResponse
                      error:(NSError **)error {
    NSError *transportError = nil;
    if (![transport connectToHost:account.imapHost
                             port:account.imapPort
                          timeout:IMBIMAPCommandTimeout
                            error:&transportError]) {
        if (error) *error = [self wrappedTransportError:transportError account:account code:125];
        return NO;
    }

    NSString *response = [self readResponseFromTransport:transport
                                                     tag:nil
                                                greeting:YES
                                                   token:token
                                                   error:&transportError];
    if (!response) {
        if (error) *error = [self wrappedTransportError:transportError account:account code:126];
        return NO;
    }

    NSString *greetingLine = [self firstCompleteLineInResponse:response];
    if (![greetingLine hasPrefix:@"* OK"] && ![greetingLine hasPrefix:@"* PREAUTH"]) {
        if (error) *error = [self errorWithCode:127
                                    description:[NSString stringWithFormat:@"Unexpected IMAP greeting: %@", greetingLine]];
        return NO;
    }

    if (![greetingLine hasPrefix:@"* PREAUTH"]) {
        NSString *login = [NSString stringWithFormat:@"A001 LOGIN %@ %@\r\n",
                           [self quotedIMAPString:account.username],
                           [self quotedIMAPString:password]];
        if (![self sendCommand:login transport:transport token:token error:&transportError]) {
            if (error) *error = [self wrappedTransportError:transportError account:account code:128];
            return NO;
        }

        response = [self readResponseFromTransport:transport tag:@"A001" greeting:NO token:token error:&transportError];
        if (!response) {
            if (error) *error = [self wrappedTransportError:transportError account:account code:129];
            return NO;
        }

        NSString *loginLine = [self completeTaggedLineForTag:@"A001" response:response];
        if (![self taggedLineIsOK:loginLine tag:@"A001"]) {
            if (error) *error = [self errorWithCode:130 description:[self messageForTaggedFailure:loginLine fallback:@"IMAP login failed."]];
            return NO;
        }
    }

    if (![self sendCommand:@"A002 SELECT \"INBOX\"\r\n" transport:transport token:token error:&transportError]) {
        if (error) *error = [self wrappedTransportError:transportError account:account code:131];
        return NO;
    }

    response = [self readResponseFromTransport:transport tag:@"A002" greeting:NO token:token error:&transportError];
    if (!response) {
        if (error) *error = [self wrappedTransportError:transportError account:account code:132];
        return NO;
    }

    NSString *selectLine = [self completeTaggedLineForTag:@"A002" response:response];
    if (![self taggedLineIsOK:selectLine tag:@"A002"]) {
        if (error) *error = [self errorWithCode:133 description:[self messageForTaggedFailure:selectLine fallback:@"Unable to open INBOX."]];
        return NO;
    }

    if (selectResponse) *selectResponse = response;
    return YES;
}

- (NSDictionary *)resultWithToken:(NSUInteger)token messages:(NSArray *)messages error:(NSError *)error {
    NSMutableDictionary *result = [NSMutableDictionary dictionary];
    [result setObject:[NSNumber numberWithUnsignedInteger:token] forKey:@"token"];
    if (messages) [result setObject:messages forKey:@"messages"];
    if (error) [result setObject:error forKey:@"error"];
    return result;
}

- (void)finishOperationOnMainThread:(NSDictionary *)result {
    NSUInteger token = [[result objectForKey:@"token"] unsignedIntegerValue];
    if (![self isOperationCurrent:token]) return;

    NSError *error = [result objectForKey:@"error"];
    NSArray *messages = [result objectForKey:@"messages"];
    id<IMBIMAPClientDelegate> delegate = _delegate;

    if (error) {
        if (delegate && [delegate respondsToSelector:@selector(imapClient:didFailWithError:)]) {
            [delegate imapClient:self didFailWithError:error];
        }
    } else {
        if (!messages) messages = [NSArray array];
        if (delegate && [delegate respondsToSelector:@selector(imapClient:didLoadMessages:)]) {
            [delegate imapClient:self didLoadMessages:messages];
        }
    }
}

- (void)finishBodyOperationOnMainThread:(NSDictionary *)result {
    NSUInteger token = [[result objectForKey:@"token"] unsignedIntegerValue];
    if (![self isOperationCurrent:token]) return;

    NSError *error = [result objectForKey:@"error"];
    NSString *body = [result objectForKey:@"body"];
    NSString *uid = [result objectForKey:@"uid"];
    id<IMBIMAPClientDelegate> delegate = _delegate;

    if (error) {
        if (delegate && [delegate respondsToSelector:@selector(imapClient:didFailWithError:)]) {
            [delegate imapClient:self didFailWithError:error];
        }
    } else if (delegate && [delegate respondsToSelector:@selector(imapClient:didLoadMessageBody:forUID:)]) {
        [delegate imapClient:self didLoadMessageBody:(body ? body : @"") forUID:uid];
    }
}

- (void)performFetchOperation:(NSDictionary *)arguments {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    IMBAccount *account = [arguments objectForKey:@"account"];
    NSString *password = [arguments objectForKey:@"password"];
    NSUInteger token = [[arguments objectForKey:@"token"] unsignedIntegerValue];

    IMBMBEDTLSTransport *transport = [[IMBMBEDTLSTransport alloc] init];
    [self setActiveTransport:transport forToken:token];
    NSError *error = nil;
    NSArray *messages = nil;

    if (![self isOperationCurrent:token]) goto done;
    if (!account.imapUseSSL) {
        error = [self errorWithCode:124 description:@"This build requires implicit SSL/TLS for IMAP. Non-TLS IMAP is disabled."];
        goto done;
    }

    NSString *selectResponse = nil;
    if (![self openInboxForAccount:account password:password transport:transport token:token selectResponse:&selectResponse error:&error]) goto done;

    NSUInteger messageCount = [self existsCountFromSelectResponse:selectResponse];
    if (messageCount == 0) {
        messages = [NSArray array];
        goto logout;
    }

    NSUInteger first = (messageCount > 25) ? (messageCount - 24) : 1;
    NSString *fetch = [NSString stringWithFormat:@"A003 FETCH %lu:%lu (UID BODY.PEEK[HEADER.FIELDS (FROM SUBJECT DATE)])\r\n",
                       (unsigned long)first,
                       (unsigned long)messageCount];
    NSError *transportError = nil;
    if (![self sendCommand:fetch transport:transport token:token error:&transportError]) {
        if ([self isOperationCurrent:token]) error = [self wrappedTransportError:transportError account:account code:134];
        goto done;
    }

    NSString *response = [self readResponseFromTransport:transport tag:@"A003" greeting:NO token:token error:&transportError];
    if (!response) {
        if ([self isOperationCurrent:token]) error = [self wrappedTransportError:transportError account:account code:135];
        goto done;
    }

    NSString *fetchLine = [self completeTaggedLineForTag:@"A003" response:response];
    if (![self taggedLineIsOK:fetchLine tag:@"A003"]) {
        error = [self errorWithCode:136 description:[self messageForTaggedFailure:fetchLine fallback:@"Unable to fetch message headers."]];
        goto done;
    }
    messages = [self messagesFromFetchResponse:response];

logout:
    if ([self isOperationCurrent:token] && [transport isConnected]) {
        NSData *logoutData = [@"A999 LOGOUT\r\n" dataUsingEncoding:NSUTF8StringEncoding];
        [transport writeData:logoutData timeout:2.0 error:NULL];
    }

done:
    [transport close];
    [self clearActiveTransportIfMatches:transport];
    if ([self isOperationCurrent:token]) {
        NSDictionary *result = [self resultWithToken:token messages:messages error:error];
        [self performSelectorOnMainThread:@selector(finishOperationOnMainThread:) withObject:result waitUntilDone:NO];
    }
    [transport release];
    [pool drain];
}

- (void)performBodyOperation:(NSDictionary *)arguments {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    IMBAccount *account = [arguments objectForKey:@"account"];
    NSString *password = [arguments objectForKey:@"password"];
    NSString *uid = [arguments objectForKey:@"uid"];
    NSUInteger token = [[arguments objectForKey:@"token"] unsignedIntegerValue];

    IMBMBEDTLSTransport *transport = [[IMBMBEDTLSTransport alloc] init];
    [self setActiveTransport:transport forToken:token];
    NSError *error = nil;
    NSString *body = nil;

    if (![self isOperationCurrent:token]) goto done;
    if (!account.imapUseSSL) {
        error = [self errorWithCode:124 description:@"This build requires implicit SSL/TLS for IMAP. Non-TLS IMAP is disabled."];
        goto done;
    }

    if (![self openInboxForAccount:account password:password transport:transport token:token selectResponse:NULL error:&error]) goto done;

    NSString *fetch = [NSString stringWithFormat:@"A004 UID FETCH %@ (BODY.PEEK[]<0.%lu>)\r\n",
                       uid,
                       (unsigned long)IMBIMAPBodyFetchLimit];
    NSError *transportError = nil;
    if (![self sendCommand:fetch transport:transport token:token error:&transportError]) {
        if ([self isOperationCurrent:token]) error = [self wrappedTransportError:transportError account:account code:140];
        goto done;
    }

    NSData *responseData = [self readResponseDataFromTransport:transport tag:@"A004" greeting:NO token:token error:&transportError];
    if (!responseData) {
        if ([self isOperationCurrent:token]) error = [self wrappedTransportError:transportError account:account code:141];
        goto done;
    }

    NSString *responseText = [self stringFromData:responseData];
    NSString *fetchLine = [self completeTaggedLineForTag:@"A004" response:responseText];
    if (![self taggedLineIsOK:fetchLine tag:@"A004"]) {
        error = [self errorWithCode:142 description:[self messageForTaggedFailure:fetchLine fallback:@"Unable to fetch the message body."]];
        goto done;
    }

    NSData *messageData = [self literalPayloadFromFetchData:responseData];
    if (!messageData) {
        error = [self errorWithCode:143 description:@"The IMAP server response did not contain a readable message literal."];
        goto done;
    }

    body = [IMBMIMETextExtractor plainTextFromMessageData:messageData];
    if (!body) body = @"";
    if ([messageData length] >= IMBIMAPBodyFetchLimit) {
        NSString *note = @"\n\n[Message preview limited to the first 256 KB for iPad 1 memory safety.]";
        body = ([body length] > 0) ? [body stringByAppendingString:note] : note;
    }

    if ([self isOperationCurrent:token] && [transport isConnected]) {
        NSData *logoutData = [@"A999 LOGOUT\r\n" dataUsingEncoding:NSUTF8StringEncoding];
        [transport writeData:logoutData timeout:2.0 error:NULL];
    }

done:
    [transport close];
    [self clearActiveTransportIfMatches:transport];
    if ([self isOperationCurrent:token]) {
        NSMutableDictionary *result = [NSMutableDictionary dictionary];
        [result setObject:[NSNumber numberWithUnsignedInteger:token] forKey:@"token"];
        [result setObject:(uid ? uid : @"") forKey:@"uid"];
        if (body) [result setObject:body forKey:@"body"];
        if (error) [result setObject:error forKey:@"error"];
        [self performSelectorOnMainThread:@selector(finishBodyOperationOnMainThread:) withObject:result waitUntilDone:NO];
    }
    [transport release];
    [pool drain];
}

- (void)fetchLatestHeadersForAccount:(IMBAccount *)account password:(NSString *)password {
    if (!account || [account.imapHost length] == 0 || account.imapPort == 0) {
        NSError *error = [self errorWithCode:102 description:@"IMAP server or port is missing."];
        id<IMBIMAPClientDelegate> delegate = _delegate;
        if (delegate && [delegate respondsToSelector:@selector(imapClient:didFailWithError:)]) [delegate imapClient:self didFailWithError:error];
        return;
    }
    if ([account.username length] == 0 || [password length] == 0) {
        NSError *error = [self errorWithCode:103 description:@"Username or password is missing."];
        id<IMBIMAPClientDelegate> delegate = _delegate;
        if (delegate && [delegate respondsToSelector:@selector(imapClient:didFailWithError:)]) [delegate imapClient:self didFailWithError:error];
        return;
    }

    [self cancel];
    NSUInteger token = 0;
    @synchronized(self) {
        _generation++;
        token = _generation;
    }

    NSDictionary *arguments = [[NSDictionary alloc] initWithObjectsAndKeys:
                               account, @"account",
                               password, @"password",
                               [NSNumber numberWithUnsignedInteger:token], @"token",
                               nil];
    [NSThread detachNewThreadSelector:@selector(performFetchOperation:) toTarget:self withObject:arguments];
    [arguments release];
}

- (void)fetchMessageBodyForAccount:(IMBAccount *)account
                          password:(NSString *)password
                               uid:(NSString *)uid {
    if (!account || [account.imapHost length] == 0 || account.imapPort == 0 || [account.username length] == 0 || [password length] == 0) {
        NSError *error = [self errorWithCode:144 description:@"The account is missing information required to load this message."];
        id<IMBIMAPClientDelegate> delegate = _delegate;
        if (delegate && [delegate respondsToSelector:@selector(imapClient:didFailWithError:)]) [delegate imapClient:self didFailWithError:error];
        return;
    }

    NSCharacterSet *nonDigits = [[NSCharacterSet decimalDigitCharacterSet] invertedSet];
    if ([uid length] == 0 || [uid rangeOfCharacterFromSet:nonDigits].location != NSNotFound) {
        NSError *error = [self errorWithCode:145 description:@"The message has an invalid IMAP UID."];
        id<IMBIMAPClientDelegate> delegate = _delegate;
        if (delegate && [delegate respondsToSelector:@selector(imapClient:didFailWithError:)]) [delegate imapClient:self didFailWithError:error];
        return;
    }

    [self cancel];
    NSUInteger token = 0;
    @synchronized(self) {
        _generation++;
        token = _generation;
    }

    NSDictionary *arguments = [[NSDictionary alloc] initWithObjectsAndKeys:
                               account, @"account",
                               password, @"password",
                               uid, @"uid",
                               [NSNumber numberWithUnsignedInteger:token], @"token",
                               nil];
    [NSThread detachNewThreadSelector:@selector(performBodyOperation:) toTarget:self withObject:arguments];
    [arguments release];
}

- (void)dealloc {
    _delegate = nil;
    [self cancel];
    @synchronized(self) {
        [_activeTransport release];
        _activeTransport = nil;
    }
    [super dealloc];
}

@end
