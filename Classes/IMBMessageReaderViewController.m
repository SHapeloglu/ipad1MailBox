#import "IMBMessageReaderViewController.h"
#import "IMBAccount.h"
#import "IMBAccountStore.h"

@implementation IMBMessageReaderViewController

- (id)initWithAccount:(IMBAccount *)account message:(NSDictionary *)message {
    self = [super init];
    if (self) {
        _account = [account retain];
        _message = [message copy];
        _client = [[IMBIMAPClient alloc] init];
        _client.delegate = self;
    }
    return self;
}

- (NSString *)headerTextWithBody:(NSString *)body {
    NSString *subject = [_message objectForKey:@"subject"];
    NSString *from = [_message objectForKey:@"from"];
    NSString *date = [_message objectForKey:@"date"];

    if ([subject length] == 0) subject = @"(No Subject)";
    if ([from length] == 0) from = @"Unknown sender";
    if ([date length] == 0) date = @"";
    if (!body) body = @"";

    return [NSString stringWithFormat:@"%@\n\nFrom: %@\nDate: %@\n\n----------------------------------------\n\n%@",
            subject,
            from,
            date,
            body];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Message";
    self.view.backgroundColor = [UIColor whiteColor];

    _textView = [[UITextView alloc] initWithFrame:self.view.bounds];
    _textView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _textView.editable = NO;
    _textView.font = [UIFont systemFontOfSize:15.0f];
    _textView.text = [self headerTextWithBody:@"Loading message body..."];
    [self.view addSubview:_textView];

    [self beginLoadingBody];
}

- (void)beginLoadingBody {
    if (_loading) return;

    NSString *uid = [_message objectForKey:@"uid"];
    if ([uid length] == 0) {
        _textView.text = [self headerTextWithBody:@"This message does not have a usable IMAP UID."];
        return;
    }

    NSString *password = [[IMBAccountStore sharedStore] passwordForAccount:_account];
    if ([password length] == 0) {
        _textView.text = [self headerTextWithBody:@"No password is stored for this account."];
        return;
    }

    _loading = YES;
    [_client fetchMessageBodyForAccount:_account password:password uid:uid];
}

- (void)imapClient:(IMBIMAPClient *)client didLoadMessageBody:(NSString *)body forUID:(NSString *)uid {
    _loading = NO;
    if ([body length] == 0) {
        body = @"No text/plain body was found in this message. HTML rendering and richer MIME support are planned for a later milestone.";
    }
    _textView.text = [self headerTextWithBody:body];
    /* Avoid the external CGPointZero constant on the old iPhoneOS 6.1 SDK/linker path. */
    [_textView setContentOffset:CGPointMake(0.0f, 0.0f) animated:NO];
}

- (void)imapClient:(IMBIMAPClient *)client didFailWithError:(NSError *)error {
    _loading = NO;
    NSString *description = [error localizedDescription];
    if ([description length] == 0) description = @"Unable to load the message body.";
    _textView.text = [self headerTextWithBody:description];

    UIAlertView *alert = [[[UIAlertView alloc] initWithTitle:@"Message Error"
                                                    message:description
                                                   delegate:nil
                                          cancelButtonTitle:@"OK"
                                          otherButtonTitles:nil] autorelease];
    [alert show];
}

- (void)dealloc {
    _client.delegate = nil;
    [_client cancel];
    [_client release];
    [_account release];
    [_message release];
    [_textView release];
    [super dealloc];
}

@end
