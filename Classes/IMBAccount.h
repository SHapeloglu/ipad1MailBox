#import <Foundation/Foundation.h>

@interface IMBAccount : NSObject {
    NSString *_displayName;
    NSString *_emailAddress;
    NSString *_username;
    NSString *_imapHost;
    NSUInteger _imapPort;
    BOOL _imapUseSSL;
    NSString *_smtpHost;
    NSUInteger _smtpPort;
    BOOL _smtpUseSSL;
}

@property (nonatomic, copy) NSString *displayName;
@property (nonatomic, copy) NSString *emailAddress;
@property (nonatomic, copy) NSString *username;
@property (nonatomic, copy) NSString *imapHost;
@property (nonatomic, assign) NSUInteger imapPort;
@property (nonatomic, assign) BOOL imapUseSSL;
@property (nonatomic, copy) NSString *smtpHost;
@property (nonatomic, assign) NSUInteger smtpPort;
@property (nonatomic, assign) BOOL smtpUseSSL;

- (NSString *)accountIdentifier;
- (NSDictionary *)dictionaryRepresentation;
+ (IMBAccount *)accountFromDictionary:(NSDictionary *)dictionary;

@end
