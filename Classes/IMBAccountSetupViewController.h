#import <UIKit/UIKit.h>

@interface IMBAccountSetupViewController : UITableViewController <UITextFieldDelegate> {
    UITextField *_emailField;
    UITextField *_usernameField;
    UITextField *_passwordField;
    UITextField *_imapField;
    UITextField *_imapPortField;
    UITextField *_smtpField;
    UITextField *_smtpPortField;
}

@end
