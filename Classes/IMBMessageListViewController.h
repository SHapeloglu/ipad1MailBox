#import <UIKit/UIKit.h>
#import "IMBIMAPClient.h"

@class IMBAccount;

@interface IMBMessageListViewController : UITableViewController <IMBIMAPClientDelegate> {
    IMBAccount *_account;
    IMBIMAPClient *_client;
    NSArray *_messages;
    NSString *_statusText;
    BOOL _loading;
}

- (id)initWithAccount:(IMBAccount *)account;

@end
