#import <Foundation/Foundation.h>

@class IMBAccount;

@interface IMBAccountStore : NSObject {
    NSMutableArray *_accounts;
}

+ (IMBAccountStore *)sharedStore;
- (NSArray *)accounts;
- (BOOL)addOrUpdateAccount:(IMBAccount *)account password:(NSString *)password keychainStatus:(NSInteger *)statusOut;
- (NSString *)passwordForAccount:(IMBAccount *)account;
- (void)removeAccount:(IMBAccount *)account;

@end
