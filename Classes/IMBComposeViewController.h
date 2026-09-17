#import <UIKit/UIKit.h>

@interface IMBComposeViewController : UIViewController <UITextFieldDelegate> {
    UITextField *_toField;
    UITextField *_subjectField;
    UITextView *_bodyView;
}

@end
