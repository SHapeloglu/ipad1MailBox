#import "IMBAccountSetupViewController.h"
#import "IMBAccount.h"
#import "IMBAccountStore.h"

@implementation IMBAccountSetupViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Add Account";

    self.navigationItem.leftBarButtonItem = [[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(cancelPressed:)] autorelease];
    self.navigationItem.rightBarButtonItem = [[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemSave target:self action:@selector(savePressed:)] autorelease];

    _emailField = [[UITextField alloc] initWithFrame:CGRectMake(130.0f, 7.0f, 330.0f, 30.0f)];
    _usernameField = [[UITextField alloc] initWithFrame:CGRectMake(130.0f, 7.0f, 330.0f, 30.0f)];
    _passwordField = [[UITextField alloc] initWithFrame:CGRectMake(130.0f, 7.0f, 330.0f, 30.0f)];
    _imapField = [[UITextField alloc] initWithFrame:CGRectMake(130.0f, 7.0f, 330.0f, 30.0f)];
    _imapPortField = [[UITextField alloc] initWithFrame:CGRectMake(130.0f, 7.0f, 120.0f, 30.0f)];
    _smtpField = [[UITextField alloc] initWithFrame:CGRectMake(130.0f, 7.0f, 330.0f, 30.0f)];
    _smtpPortField = [[UITextField alloc] initWithFrame:CGRectMake(130.0f, 7.0f, 120.0f, 30.0f)];

    NSArray *fields = [NSArray arrayWithObjects:_emailField, _usernameField, _passwordField, _imapField, _imapPortField, _smtpField, _smtpPortField, nil];
    for (UITextField *field in fields) {
        field.delegate = self;
        field.autocorrectionType = UITextAutocorrectionTypeNo;
        field.autocapitalizationType = UITextAutocapitalizationTypeNone;
        field.clearButtonMode = UITextFieldViewModeWhileEditing;
        field.returnKeyType = UIReturnKeyNext;
    }

    _emailField.placeholder = @"name@example.com";
    _emailField.keyboardType = UIKeyboardTypeEmailAddress;
    _usernameField.placeholder = @"Usually your email address";
    _passwordField.placeholder = @"Password / app password (required)";
    _passwordField.secureTextEntry = YES;
    _imapField.placeholder = @"imap.example.com";
    _imapPortField.text = @"993";
    _imapPortField.keyboardType = UIKeyboardTypeNumberPad;
    _smtpField.placeholder = @"smtp.example.com";
    _smtpPortField.text = @"587";
    _smtpPortField.keyboardType = UIKeyboardTypeNumberPad;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return section == 0 ? 3 : 4;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return section == 0 ? @"Account" : @"Servers";
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSString *identifier = [NSString stringWithFormat:@"FieldCell-%ld-%ld", (long)indexPath.section, (long)indexPath.row];
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];
    if (!cell) {
        cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:identifier] autorelease];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
    }

    UITextField *field = nil;
    if (indexPath.section == 0) {
        if (indexPath.row == 0) { cell.textLabel.text = @"Email"; field = _emailField; }
        if (indexPath.row == 1) { cell.textLabel.text = @"Username"; field = _usernameField; }
        if (indexPath.row == 2) { cell.textLabel.text = @"Password"; field = _passwordField; }
    } else {
        if (indexPath.row == 0) { cell.textLabel.text = @"IMAP"; field = _imapField; }
        if (indexPath.row == 1) { cell.textLabel.text = @"IMAP Port"; field = _imapPortField; }
        if (indexPath.row == 2) { cell.textLabel.text = @"SMTP"; field = _smtpField; }
        if (indexPath.row == 3) { cell.textLabel.text = @"SMTP Port"; field = _smtpPortField; }
    }

    if (field && field.superview != cell.contentView) {
        [field removeFromSuperview];
        [cell.contentView addSubview:field];
    }
    return cell;
}

- (void)applyProviderDefaultsIfNeeded {
    NSString *email = [_emailField.text lowercaseString];
    NSRange atRange = [email rangeOfString:@"@" options:NSBackwardsSearch];
    if (atRange.location == NSNotFound || atRange.location + 1 >= [email length]) return;

    NSString *domain = [email substringFromIndex:atRange.location + 1];
    if ([_usernameField.text length] == 0) _usernameField.text = _emailField.text;

    if ([_imapField.text length] == 0) {
        if ([domain isEqualToString:@"gmail.com"] || [domain isEqualToString:@"googlemail.com"]) {
            _imapField.text = @"imap.gmail.com";
        } else if ([domain isEqualToString:@"icloud.com"] || [domain isEqualToString:@"me.com"] || [domain isEqualToString:@"mac.com"]) {
            _imapField.text = @"imap.mail.me.com";
        } else if ([domain isEqualToString:@"yahoo.com"]) {
            _imapField.text = @"imap.mail.yahoo.com";
        } else {
            _imapField.text = [NSString stringWithFormat:@"imap.%@", domain];
        }
    }

    if ([_smtpField.text length] == 0) {
        if ([domain isEqualToString:@"gmail.com"] || [domain isEqualToString:@"googlemail.com"]) {
            _smtpField.text = @"smtp.gmail.com";
        } else if ([domain isEqualToString:@"icloud.com"] || [domain isEqualToString:@"me.com"] || [domain isEqualToString:@"mac.com"]) {
            _smtpField.text = @"smtp.mail.me.com";
        } else if ([domain isEqualToString:@"yahoo.com"]) {
            _smtpField.text = @"smtp.mail.yahoo.com";
        } else {
            _smtpField.text = [NSString stringWithFormat:@"smtp.%@", domain];
        }
    }
}

- (void)savePressed:(id)sender {
    [self applyProviderDefaultsIfNeeded];

    if ([_emailField.text length] == 0 || [_usernameField.text length] == 0 ||
        [_passwordField.text length] == 0 || [_imapField.text length] == 0 ||
        [_smtpField.text length] == 0) {
        UIAlertView *alert = [[[UIAlertView alloc] initWithTitle:@"Missing Information"
                                                        message:@"Email, username, password, IMAP and SMTP server fields are required."
                                                       delegate:nil
                                              cancelButtonTitle:@"OK"
                                              otherButtonTitles:nil] autorelease];
        [alert show];
        return;
    }

    IMBAccount *account = [[[IMBAccount alloc] init] autorelease];
    account.displayName = _emailField.text;
    account.emailAddress = _emailField.text;
    account.username = _usernameField.text;
    account.imapHost = _imapField.text;
    account.imapPort = (NSUInteger)[_imapPortField.text integerValue];
    account.imapUseSSL = YES;
    account.smtpHost = _smtpField.text;
    account.smtpPort = (NSUInteger)[_smtpPortField.text integerValue];
    account.smtpUseSSL = YES;

    NSInteger keychainStatus = 0;
    BOOL saved = [[IMBAccountStore sharedStore] addOrUpdateAccount:account
                                                          password:_passwordField.text
                                                    keychainStatus:&keychainStatus];
    if (!saved) {
        NSString *message = [NSString stringWithFormat:@"The password could not be stored securely in Keychain. Error code: %ld", (long)keychainStatus];
        UIAlertView *alert = [[[UIAlertView alloc] initWithTitle:@"Keychain Error"
                                                        message:message
                                                       delegate:nil
                                              cancelButtonTitle:@"OK"
                                              otherButtonTitles:nil] autorelease];
        [alert show];
        return;
    }

    [self dismissModalViewControllerAnimated:YES];
}

- (void)cancelPressed:(id)sender {
    [self dismissModalViewControllerAnimated:YES];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    if (textField == _emailField) [_usernameField becomeFirstResponder];
    else if (textField == _usernameField) [_passwordField becomeFirstResponder];
    else if (textField == _passwordField) [_imapField becomeFirstResponder];
    else if (textField == _imapField) [_imapPortField becomeFirstResponder];
    else if (textField == _imapPortField) [_smtpField becomeFirstResponder];
    else if (textField == _smtpField) [_smtpPortField becomeFirstResponder];
    else [textField resignFirstResponder];
    return YES;
}

- (void)dealloc {
    [_emailField release];
    [_usernameField release];
    [_passwordField release];
    [_imapField release];
    [_imapPortField release];
    [_smtpField release];
    [_smtpPortField release];
    [super dealloc];
}

@end
