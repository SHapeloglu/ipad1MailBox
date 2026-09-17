#import "IMBInboxViewController.h"
#import "IMBAccountStore.h"
#import "IMBAccount.h"
#import "IMBAccountSetupViewController.h"
#import "IMBComposeViewController.h"

@implementation IMBInboxViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Mailboxes";

    UIBarButtonItem *addButton = [[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(addAccountPressed:)] autorelease];
    UIBarButtonItem *composeButton = [[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCompose target:self action:@selector(composePressed:)] autorelease];
    self.navigationItem.leftBarButtonItem = addButton;
    self.navigationItem.rightBarButtonItem = composeButton;

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(accountsChanged:) name:@"IMBAccountsDidChangeNotification" object:nil];
}

- (void)accountsChanged:(NSNotification *)notification {
    [self reloadAccounts];
}

- (void)reloadAccounts {
    [self.tableView reloadData];
}

- (void)addAccountPressed:(id)sender {
    IMBAccountSetupViewController *setup = [[[IMBAccountSetupViewController alloc] initWithStyle:UITableViewStyleGrouped] autorelease];
    UINavigationController *navigation = [[[UINavigationController alloc] initWithRootViewController:setup] autorelease];
    navigation.modalPresentationStyle = UIModalPresentationFormSheet;
    [self presentModalViewController:navigation animated:YES];
}

- (void)composePressed:(id)sender {
    if ([[[IMBAccountStore sharedStore] accounts] count] == 0) {
        UIAlertView *alert = [[[UIAlertView alloc] initWithTitle:@"No Account"
                                                        message:@"Add a mail account before composing a message."
                                                       delegate:nil
                                              cancelButtonTitle:@"OK"
                                              otherButtonTitles:nil] autorelease];
        [alert show];
        return;
    }

    IMBComposeViewController *compose = [[[IMBComposeViewController alloc] init] autorelease];
    UINavigationController *navigation = [[[UINavigationController alloc] initWithRootViewController:compose] autorelease];
    navigation.modalPresentationStyle = UIModalPresentationFormSheet;
    [self presentModalViewController:navigation animated:YES];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    NSUInteger count = [[[IMBAccountStore sharedStore] accounts] count];
    return count == 0 ? 1 : (NSInteger)count;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return @"Accounts";
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *identifier = @"MailboxCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];
    if (!cell) {
        cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:identifier] autorelease];
    }

    NSArray *accounts = [[IMBAccountStore sharedStore] accounts];
    if ([accounts count] == 0) {
        cell.textLabel.text = @"No mail account";
        cell.detailTextLabel.text = @"Tap + to add an IMAP/SMTP account";
        cell.accessoryType = UITableViewCellAccessoryNone;
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
    } else {
        IMBAccount *account = [accounts objectAtIndex:indexPath.row];
        cell.textLabel.text = account.displayName ? account.displayName : account.emailAddress;
        cell.detailTextLabel.text = [NSString stringWithFormat:@"IMAP %@:%lu", account.imapHost, (unsigned long)account.imapPort];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        cell.selectionStyle = UITableViewCellSelectionStyleBlue;
    }
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    NSArray *accounts = [[IMBAccountStore sharedStore] accounts];
    if ([accounts count] == 0) return;

    IMBAccount *account = [accounts objectAtIndex:indexPath.row];
    UIViewController *detail = [[[UIViewController alloc] init] autorelease];
    detail.title = @"Inbox";
    detail.view.backgroundColor = [UIColor whiteColor];

    UILabel *label = [[[UILabel alloc] initWithFrame:CGRectMake(40.0f, 80.0f, 520.0f, 100.0f)] autorelease];
    label.backgroundColor = [UIColor clearColor];
    label.numberOfLines = 0;
    label.textAlignment = UITextAlignmentCenter;
    label.text = [NSString stringWithFormat:@"%@\n\nIMAP message loading will be enabled in the next transport milestone.", account.emailAddress];
    [detail.view addSubview:label];

    UISplitViewController *split = (UISplitViewController *)self.splitViewController;
    if (split && [split.viewControllers count] >= 2) {
        UINavigationController *detailNavigation = [[[UINavigationController alloc] initWithRootViewController:detail] autorelease];
        split.viewControllers = [NSArray arrayWithObjects:[split.viewControllers objectAtIndex:0], detailNavigation, nil];
    }
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [super dealloc];
}

@end
