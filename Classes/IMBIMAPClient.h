#import <Foundation/Foundation.h>

@class IMBAccount;
@class IMBIMAPClient;

@protocol IMBIMAPClientDelegate <NSObject>
- (void)imapClient:(IMBIMAPClient *)client didLoadMessages:(NSArray *)messages;
- (void)imapClient:(IMBIMAPClient *)client didFailWithError:(NSError *)error;
@end

@interface IMBIMAPClient : NSObject <NSStreamDelegate> {
    NSInputStream *_inputStream;
    NSOutputStream *_outputStream;
    NSMutableData *_receiveBuffer;
    IMBAccount *_account;
    NSString *_password;
    NSTimer *_timeoutTimer;
    id<IMBIMAPClientDelegate> _delegate;
    NSInteger _state;
    NSUInteger _messageCount;
    BOOL _finished;
}

@property (nonatomic, assign) id<IMBIMAPClientDelegate> delegate;

- (void)fetchLatestHeadersForAccount:(IMBAccount *)account password:(NSString *)password;
- (void)cancel;

@end
