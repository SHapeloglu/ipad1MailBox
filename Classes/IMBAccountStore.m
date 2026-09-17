#import "IMBAccountStore.h"
#import "IMBAccount.h"
#import <Security/Security.h>

static NSString * const IMBAccountsDefaultsKey = @"IMBAccounts";
static NSString * const IMBKeychainService = @"com.shapeloglu.ipad1mailbox";

@implementation IMBAccountStore

+ (IMBAccountStore *)sharedStore {
    static IMBAccountStore *store = nil;
    @synchronized(self) {
        if (!store) {
            store = [[IMBAccountStore alloc] init];
        }
    }
    return store;
}

- (id)init {
    self = [super init];
    if (self) {
        _accounts = [[NSMutableArray alloc] init];
        NSArray *saved = [[NSUserDefaults standardUserDefaults] objectForKey:IMBAccountsDefaultsKey];
        NSEnumerator *enumerator = [saved objectEnumerator];
        NSDictionary *dictionary = nil;
        while ((dictionary = [enumerator nextObject])) {
            IMBAccount *account = [IMBAccount accountFromDictionary:dictionary];
            if (account) [_accounts addObject:account];
        }
    }
    return self;
}

- (NSArray *)accounts {
    return _accounts;
}

- (void)persistMetadata {
    NSMutableArray *serialized = [NSMutableArray arrayWithCapacity:[_accounts count]];
    NSEnumerator *enumerator = [_accounts objectEnumerator];
    IMBAccount *account = nil;
    while ((account = [enumerator nextObject])) {
        [serialized addObject:[account dictionaryRepresentation]];
    }
    [[NSUserDefaults standardUserDefaults] setObject:serialized forKey:IMBAccountsDefaultsKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (NSMutableDictionary *)keychainQueryForAccount:(IMBAccount *)account {
    NSMutableDictionary *query = [NSMutableDictionary dictionary];
    [query setObject:(id)kSecClassGenericPassword forKey:(id)kSecClass];
    [query setObject:IMBKeychainService forKey:(id)kSecAttrService];
    [query setObject:[account accountIdentifier] forKey:(id)kSecAttrAccount];
    return query;
}

- (void)storePassword:(NSString *)password forAccount:(IMBAccount *)account {
    if (!password || [password length] == 0) return;

    NSMutableDictionary *query = [self keychainQueryForAccount:account];
    NSData *passwordData = [password dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *attributes = [NSDictionary dictionaryWithObject:passwordData forKey:(id)kSecValueData];
    OSStatus status = SecItemUpdate((CFDictionaryRef)query, (CFDictionaryRef)attributes);

    if (status == errSecItemNotFound) {
        [query setObject:passwordData forKey:(id)kSecValueData];
        [query setObject:(id)kSecAttrAccessibleWhenUnlocked forKey:(id)kSecAttrAccessible];
        SecItemAdd((CFDictionaryRef)query, NULL);
    }
}

- (void)addOrUpdateAccount:(IMBAccount *)account password:(NSString *)password {
    if (!account) return;

    NSUInteger existingIndex = NSNotFound;
    NSUInteger index = 0;
    for (IMBAccount *existing in _accounts) {
        if ([[existing accountIdentifier] isEqualToString:[account accountIdentifier]]) {
            existingIndex = index;
            break;
        }
        index++;
    }

    if (existingIndex == NSNotFound) {
        [_accounts addObject:account];
    } else {
        [_accounts replaceObjectAtIndex:existingIndex withObject:account];
    }

    [self persistMetadata];
    [self storePassword:password forAccount:account];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"IMBAccountsDidChangeNotification" object:self];
}

- (NSString *)passwordForAccount:(IMBAccount *)account {
    NSMutableDictionary *query = [self keychainQueryForAccount:account];
    [query setObject:(id)kCFBooleanTrue forKey:(id)kSecReturnData];
    [query setObject:(id)kSecMatchLimitOne forKey:(id)kSecMatchLimit];

    CFTypeRef result = NULL;
    OSStatus status = SecItemCopyMatching((CFDictionaryRef)query, &result);
    if (status != errSecSuccess || !result) return nil;

    NSData *data = [(NSData *)result autorelease];
    NSString *password = [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] autorelease];
    return password;
}

- (void)removeAccount:(IMBAccount *)account {
    if (!account) return;
    SecItemDelete((CFDictionaryRef)[self keychainQueryForAccount:account]);
    [_accounts removeObject:account];
    [self persistMetadata];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"IMBAccountsDidChangeNotification" object:self];
}

- (void)dealloc {
    [_accounts release];
    [super dealloc];
}

@end
