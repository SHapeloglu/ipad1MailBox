#import "IMBMessageListViewController.h"
#import "IMBAccount.h"
#import "IMBAccountStore.h"

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
    self.navigationItem.rightBarButtonItem = refresh;

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
    NSString *subject = [message objectForKey:@"subject"];
    if ([subject length] == 0) subject = @"Message";

    UIAlertView *alert = [[[UIAlertView alloc] initWithTitle:subject
                                                    message:@"The IMAP header was loaded successfully. Full message body loading is the next milestone."
                                                   delegate:nil
                                          cancelButtonTitle:@"OK"
                                          otherButtonTitles:nil] autorelease];
    [alert show];
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}

- (void)imapClient:(IMBIMAPClient *)client didLoadMessages:(NSArray *)messages {
    _loading = NO;
    [_messages release];
    _messages = [messages copy];

    if ([_messages count] == 0) {
        [self setStatusText:@"INBOX is empty."];
    } else {
        [self setStatusText:[NSString stringWithFormat:@"Loaded %lu messages", (unsigned long)[_messages count]]];
    }
    [self.tableView reloadData];
}

- (void)imapClient:(IMBIMAPClient *)client didFailWithError:(NSError *)error {
    _loading = NO;
    [self setStatusText:[error localizedDescription]];
    [self.tableView reloadData];

    UIAlertView *alert = [[[UIAlertView alloc] initWithTitle:@"IMAP Error"
                                                    message:[error localizedDescription]
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
    [super dealloc];
}

@end
