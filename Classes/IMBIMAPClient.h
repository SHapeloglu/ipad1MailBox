#import <Foundation/Foundation.h>

@class IMBAccount;
@class IMBIMAPClient;
@class IMBMBEDTLSTransport;

@protocol IMBIMAPClientDelegate <NSObject>
@optional
- (void)imapClient:(IMBIMAPClient *)client didLoadMessages:(NSArray *)messages;
- (void)imapClient:(IMBIMAPClient *)client didLoadMessageBody:(NSString *)body forUID:(NSString *)uid;
- (void)imapClient:(IMBIMAPClient *)client didFailWithError:(NSError *)error;
@end

@interface IMBIMAPClient : NSObject {
    id<IMBIMAPClientDelegate> _delegate;
    IMBMBEDTLSTransport *_activeTransport;
    NSUInteger _generation;
}

@property (nonatomic, assign) id<IMBIMAPClientDelegate> delegate;

- (void)fetchLatestHeadersForAccount:(IMBAccount *)account password:(NSString *)password;
- (void)fetchMessageBodyForAccount:(IMBAccount *)account
                          password:(NSString *)password
                               uid:(NSString *)uid;
- (void)cancel;

@end
