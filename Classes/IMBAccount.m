#import "IMBAccount.h"

@implementation IMBAccount

@synthesize displayName = _displayName;
@synthesize emailAddress = _emailAddress;
@synthesize username = _username;
@synthesize imapHost = _imapHost;
@synthesize imapPort = _imapPort;
@synthesize imapUseSSL = _imapUseSSL;
@synthesize smtpHost = _smtpHost;
@synthesize smtpPort = _smtpPort;
@synthesize smtpUseSSL = _smtpUseSSL;

- (id)init {
    self = [super init];
    if (self) {
        _imapPort = 993;
        _imapUseSSL = YES;
        _smtpPort = 587;
        _smtpUseSSL = YES;
    }
    return self;
}

- (NSString *)accountIdentifier {
    NSString *email = self.emailAddress ? self.emailAddress : @"";
    NSString *host = self.imapHost ? self.imapHost : @"";
    return [NSString stringWithFormat:@"%@@%@", email, host];
}

- (NSDictionary *)dictionaryRepresentation {
    NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
    if (self.displayName) [dictionary setObject:self.displayName forKey:@"displayName"];
    if (self.emailAddress) [dictionary setObject:self.emailAddress forKey:@"emailAddress"];
    if (self.username) [dictionary setObject:self.username forKey:@"username"];
    if (self.imapHost) [dictionary setObject:self.imapHost forKey:@"imapHost"];
    if (self.smtpHost) [dictionary setObject:self.smtpHost forKey:@"smtpHost"];
    [dictionary setObject:[NSNumber numberWithUnsignedInteger:self.imapPort] forKey:@"imapPort"];
    [dictionary setObject:[NSNumber numberWithBool:self.imapUseSSL] forKey:@"imapUseSSL"];
    [dictionary setObject:[NSNumber numberWithUnsignedInteger:self.smtpPort] forKey:@"smtpPort"];
    [dictionary setObject:[NSNumber numberWithBool:self.smtpUseSSL] forKey:@"smtpUseSSL"];
    return dictionary;
}

+ (IMBAccount *)accountFromDictionary:(NSDictionary *)dictionary {
    IMBAccount *account = [[[IMBAccount alloc] init] autorelease];
    account.displayName = [dictionary objectForKey:@"displayName"];
    account.emailAddress = [dictionary objectForKey:@"emailAddress"];
    account.username = [dictionary objectForKey:@"username"];
    account.imapHost = [dictionary objectForKey:@"imapHost"];
    account.smtpHost = [dictionary objectForKey:@"smtpHost"];

    NSNumber *imapPort = [dictionary objectForKey:@"imapPort"];
    NSNumber *imapUseSSL = [dictionary objectForKey:@"imapUseSSL"];
    NSNumber *smtpPort = [dictionary objectForKey:@"smtpPort"];
    NSNumber *smtpUseSSL = [dictionary objectForKey:@"smtpUseSSL"];

    if (imapPort) account.imapPort = [imapPort unsignedIntegerValue];
    if (imapUseSSL) account.imapUseSSL = [imapUseSSL boolValue];
    if (smtpPort) account.smtpPort = [smtpPort unsignedIntegerValue];
    if (smtpUseSSL) account.smtpUseSSL = [smtpUseSSL boolValue];
    return account;
}

- (void)dealloc {
    [_displayName release];
    [_emailAddress release];
    [_username release];
    [_imapHost release];
    [_smtpHost release];
    [super dealloc];
}

@end
