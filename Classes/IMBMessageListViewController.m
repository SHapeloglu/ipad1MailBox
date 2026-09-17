#import "IMBMessageListViewController.h"
#import "IMBAccount.h"
#import "IMBAccountStore.h"
#import "IMBTLSDiagnostics.h"
#import "IMBModernTLSProbe.h"
#import "IMBRFC2047Decoder.h"
#import "IMBMessageReaderViewController.h"

@implementation IMBMessageListViewController

- (id)initWithAccount:(IMBAccount *)account {
    self = [super initWithStyle:UITableViewStylePlain];
    if (self) {
        _account = [account retain];
        _client = [[IMBIMAPClient alloc] init];
        _client.delegate = self;
        _statusText = [@"Ready" copy];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Inbox";
    self.tableView.rowHeight = 64.0f;

    UIBarButtonItem *refresh = [[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh
                                                                              target:self
                                                                              action:@selector(refreshPressed:)] autorelease];
    UIBarButtonItem *tls = [[[UIBarButtonItem alloc] initWithTitle:@"TLS"
                                                             style:UIBarButtonItemStyleBordered
                                                            target:self
                                                            action:@selector(tlsDiagnosticsPressed:)] autorelease];
    self.navigationItem.rightBarButtonItems = [NSArray arrayWithObjects:refresh, tls, nil];

    [self beginLoading];
}

- (void)setStatusText:(NSString *)text {
    [_statusText release];
    _statusText = [text copy];
}

- (void)beginLoading {
    if (_loading) return;

    NSString *password = [[IMBAccountStore sharedStore] passwordForAccount:_account];
    if ([password length] == 0) {
        [self setStatusText:@"No password is stored for this account. Remove and add the account again."];
        [self.tableView reloadData];
        return;
    }

    _loading = YES;
    [_messages release];
    _messages = nil;
    [self setStatusText:[NSString stringWithFormat:@"Connecting to %@:%lu...",
                         _account.imapHost,
                         (unsigned long)_account.imapPort]];
    [self.tableView reloadData];

    [_client fetchLatestHeadersForAccount:_account password:password];
}

- (void)refreshPressed:(id)sender {
    [_client cancel];
    _loading = NO;
    [self beginLoading];
}

- (void)tlsDiagnosticsPressed:(id)sender {
    NSString *report = [IMBTLSDiagnostics diagnosticReportForHost:_account.imapHost port:_account.imapPort];

    UIViewController *controller = [[[UIViewController alloc] init] autorelease];
    controller.title = @"TLS Diagnostics";
    controller.view.backgroundColor = [UIColor whiteColor];

    UITextView *textView = [[[UITextView alloc] initWithFrame:controller.view.bounds] autorelease];
    textView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    textView.editable = NO;
    textView.font = [UIFont fontWithName:@"Courier" size:12.0f];
    if (!textView.font) textView.font = [UIFont systemFontOfSize:12.0f];
    textView.text = [NSString stringWithFormat:@"%@\n\n--- Modern TLS transport ---\nStarting Mbed TLS 3.6.7 probe...", report];
    [controller.view addSubview:textView];

    [_diagnosticsTextView release];
    _diagnosticsTextView = [textView retain];

    controller.navigationItem.rightBarButtonItem = [[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                                                                    target:self
                                                                                                    action:@selector(closeDiagnostics:)] autorelease];

    UINavigationController *navigation = [[[UINavigationController alloc] initWithRootViewController:controller] autorelease];
    navigation.modalPresentationStyle = UIModalPresentationFormSheet;
    [self presentModalViewController:navigation animated:YES];

    [IMBModernTLSProbe runForHost:_account.imapHost
                             port:_account.imapPort
                           target:self
                         selector:@selector(modernTLSProbeFinished:)];
}

- (void)modernTLSProbeFinished:(NSString *)report {
    if (!_diagnosticsTextView) return;

    NSString *existing = _diagnosticsTextView.text ? _diagnosticsTextView.text : @"";
    NSRange marker = [existing rangeOfString:@"--- Modern TLS transport ---"];
    if (marker.location != NSNotFound) existing = [existing substringToIndex:marker.location];

    _diagnosticsTextView.text = [NSString stringWithFormat:@"%@--- Modern TLS transport ---\n%@",
                                 existing,
                                 report ? report : @"Probe returned no report.\n"];
    if ([_diagnosticsTextView.text length] > 0) {
        NSRange endRange = NSMakeRange([_diagnosticsTextView.text length] - 1, 1);
        [_diagnosticsTextView scrollRangeToVisible:endRange];
    }
}

- (void)closeDiagnostics:(id)sender {
    [_diagnosticsTextView release];
    _diagnosticsTextView = nil;
    [self dismissModalViewControllerAnimated:YES];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if ([_messages count] > 0) return (NSInteger)[_messages count];
    return 1;
}

- (UITableViewCell *)statusCellForTableView:(UITableView *)tableView {
    static NSString *identifier = @"IMAPStatusCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];
    if (!cell) {
        cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:identifier] autorelease];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        cell.textLabel.numberOfLines = 0;
        cell.textLabel.textAlignment = UITextAlignmentCenter;
        cell.textLabel.font = [UIFont systemFontOfSize:15.0f];
    }
    cell.textLabel.text = _statusText ? _statusText : @"";
    cell.detailTextLabel.text = _loading ? @"Please wait..." : @"";
    return cell;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if ([_messages count] == 0) return [self statusCellForTableView:tableView];

    static NSString *identifier = @"IMAPMessageCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];
    if (!cell) {
        cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:identifier] autorelease];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        cell.detailTextLabel.numberOfLines = 2;
        cell.detailTextLabel.font = [UIFont systemFontOfSize:12.0f];
    }

    NSDictionary *message = [_messages objectAtIndex:(NSUInteger)indexPath.row];
    NSString *subject = [message objectForKey:@"subject"];
    NSString *from = [message objectForKey:@"from"];
    NSString *date = [message objectForKey:@"date"];

    if ([subject length] == 0) subject = @"(No Subject)";
    if ([from length] == 0) from = @"Unknown sender";
    if ([date length] == 0) date = @"";

    cell.textLabel.text = subject;
    cell.detailTextLabel.text = [NSString stringWithFormat:@"%@\n%@", from, date];
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if ([_messages count] == 0) return;

    NSDictionary *message = [_messages objectAtIndex:(NSUInteger)indexPath.row];
    IMBMessageReaderViewController *reader = [[[IMBMessageReaderViewController alloc] initWithAccount:_account
                                                                                              message:message] autorelease];
    [self.navigationController pushViewController:reader animated:YES];
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}

- (void)imapClient:(IMBIMAPClient *)client didLoadMessages:(NSArray *)messages {
    _loading = NO;
    [_messages release];

    NSMutableArray *decodedMessages = [NSMutableArray arrayWithCapacity:[messages count]];
    for (NSDictionary *message in messages) {
        NSMutableDictionary *decodedMessage = [[message mutableCopy] autorelease];

        NSString *subject = [decodedMessage objectForKey:@"subject"];
        if ([subject length] > 0) {
            NSString *decodedSubject = [IMBRFC2047Decoder decodeHeaderValue:subject];
            if (decodedSubject) [decodedMessage setObject:decodedSubject forKey:@"subject"];
        }

        NSString *from = [decodedMessage objectForKey:@"from"];
        if ([from length] > 0) {
            NSString *decodedFrom = [IMBRFC2047Decoder decodeHeaderValue:from];
            if (decodedFrom) [decodedMessage setObject:decodedFrom forKey:@"from"];
        }

        [decodedMessages addObject:decodedMessage];
    }
    _messages = [decodedMessages copy];

    if ([_messages count] == 0) [self setStatusText:@"INBOX is empty."];
    else [self setStatusText:[NSString stringWithFormat:@"Loaded %lu messages", (unsigned long)[_messages count]]];
    [self.tableView reloadData];
}

- (void)imapClient:(IMBIMAPClient *)client didFailWithError:(NSError *)error {
    _loading = NO;
    [self setStatusText:[error localizedDescription]];
    [self.tableView reloadData];

    NSString *message = [NSString stringWithFormat:@"%@\n\nTap TLS in the Inbox toolbar to inspect SecureTransport and run the Mbed TLS probe.", [error localizedDescription]];
    UIAlertView *alert = [[[UIAlertView alloc] initWithTitle:@"IMAP Error"
                                                    message:message
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
    [_messages release];
    [_statusText release];
    [_diagnosticsTextView release];
    [super dealloc];
}

@end
