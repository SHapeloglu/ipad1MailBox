#import <Foundation/Foundation.h>

@class IMBAccount;

@interface IMBAccountStore : NSObject {
    NSMutableArray *_accounts;
}

+ (IMBAccountStore *)sharedStore;
- (NSArray *)accounts;
- (void)addOrUpdateAccount:(IMBAccount *)account password:(NSString *)password;
- (NSString *)passwordForAccount:(IMBAccount *)account;
- (void)removeAccount:(IMBAccount *)account;

@end
