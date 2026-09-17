#import <Foundation/Foundation.h>

@class IMBAccount;
@class IMBIMAPClient;
@class IMBMBEDTLSTransport;

@protocol IMBIMAPClientDelegate <NSObject>
- (void)imapClient:(IMBIMAPClient *)client didLoadMessages:(NSArray *)messages;
- (void)imapClient:(IMBIMAPClient *)client didFailWithError:(NSError *)error;
@end

@interface IMBIMAPClient : NSObject {
    id<IMBIMAPClientDelegate> _delegate;
    IMBMBEDTLSTransport *_activeTransport;
    NSUInteger _generation;
}

@property (nonatomic, assign) id<IMBIMAPClientDelegate> delegate;

- (void)fetchLatestHeadersForAccount:(IMBAccount *)account password:(NSString *)password;
- (void)cancel;

@end
