#import "IMBComposeViewController.h"

@implementation IMBComposeViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"New Message";
    self.view.backgroundColor = [UIColor whiteColor];

    self.navigationItem.leftBarButtonItem = [[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(cancelPressed:)] autorelease];
    self.navigationItem.rightBarButtonItem = [[[UIBarButtonItem alloc] initWithTitle:@"Send" style:UIBarButtonItemStyleDone target:self action:@selector(sendPressed:)] autorelease];

    UILabel *toLabel = [[[UILabel alloc] initWithFrame:CGRectMake(20.0f, 20.0f, 70.0f, 32.0f)] autorelease];
    toLabel.text = @"To:";
    toLabel.backgroundColor = [UIColor clearColor];
    [self.view addSubview:toLabel];

    _toField = [[UITextField alloc] initWithFrame:CGRectMake(90.0f, 20.0f, 420.0f, 32.0f)];
    _toField.borderStyle = UITextBorderStyleRoundedRect;
    _toField.keyboardType = UIKeyboardTypeEmailAddress;
    _toField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    _toField.autocorrectionType = UITextAutocorrectionTypeNo;
    _toField.delegate = self;
    [self.view addSubview:_toField];

    UILabel *subjectLabel = [[[UILabel alloc] initWithFrame:CGRectMake(20.0f, 66.0f, 70.0f, 32.0f)] autorelease];
    subjectLabel.text = @"Subject:";
    subjectLabel.backgroundColor = [UIColor clearColor];
    [self.view addSubview:subjectLabel];

    _subjectField = [[UITextField alloc] initWithFrame:CGRectMake(90.0f, 66.0f, 420.0f, 32.0f)];
    _subjectField.borderStyle = UITextBorderStyleRoundedRect;
    _subjectField.autocorrectionType = UITextAutocorrectionTypeNo;
    _subjectField.delegate = self;
    [self.view addSubview:_subjectField];

    _bodyView = [[UITextView alloc] initWithFrame:CGRectMake(20.0f, 112.0f, 490.0f, 390.0f)];
    _bodyView.font = [UIFont systemFontOfSize:16.0f];
    _bodyView.layer.borderWidth = 1.0f;
    _bodyView.layer.borderColor = [[UIColor lightGrayColor] CGColor];
    [self.view addSubview:_bodyView];

    [_toField becomeFirstResponder];
}

- (void)sendPressed:(id)sender {
    if ([_toField.text length] == 0) {
        UIAlertView *alert = [[[UIAlertView alloc] initWithTitle:@"Recipient Required"
                                                        message:@"Enter at least one recipient."
                                                       delegate:nil
                                              cancelButtonTitle:@"OK"
                                              otherButtonTitles:nil] autorelease];
        [alert show];
        return;
    }

    UIAlertView *alert = [[[UIAlertView alloc] initWithTitle:@"SMTP Not Enabled Yet"
                                                    message:@"The compose screen is ready. SMTP transport will be connected in the next milestone after the first iPad 1 device build is verified."
                                                   delegate:nil
                                          cancelButtonTitle:@"OK"
                                          otherButtonTitles:nil] autorelease];
    [alert show];
}

- (void)cancelPressed:(id)sender {
    [self dismissModalViewControllerAnimated:YES];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    if (textField == _toField) {
        [_subjectField becomeFirstResponder];
    } else {
        [_bodyView becomeFirstResponder];
    }
    return YES;
}

- (void)dealloc {
    [_toField release];
    [_subjectField release];
    [_bodyView release];
    [super dealloc];
}

@end
