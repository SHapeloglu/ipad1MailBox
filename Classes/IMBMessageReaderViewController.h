#import <UIKit/UIKit.h>
#import "IMBIMAPClient.h"

@class IMBAccount;

@interface IMBMessageReaderViewController : UIViewController <IMBIMAPClientDelegate> {
    IMBAccount *_account;
    NSDictionary *_message;
    IMBIMAPClient *_client;
    UITextView *_textView;
    BOOL _loading;
}

- (id)initWithAccount:(IMBAccount *)account message:(NSDictionary *)message;

@end
