#import "IMBAppDelegate.h"
#import "IMBInboxViewController.h"

@implementation IMBAppDelegate

@synthesize window = _window;

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    self.window = [[[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]] autorelease];

    IMBInboxViewController *mailboxes = [[[IMBInboxViewController alloc] initWithStyle:UITableViewStyleGrouped] autorelease];
    UINavigationController *masterNavigation = [[[UINavigationController alloc] initWithRootViewController:mailboxes] autorelease];

    UIViewController *welcome = [[[UIViewController alloc] init] autorelease];
    welcome.title = @"iPad1MailBox";
    welcome.view.backgroundColor = [UIColor whiteColor];

    UILabel *titleLabel = [[[UILabel alloc] initWithFrame:CGRectMake(60.0f, 120.0f, 520.0f, 120.0f)] autorelease];
    titleLabel.backgroundColor = [UIColor clearColor];
    titleLabel.textAlignment = UITextAlignmentCenter;
    titleLabel.numberOfLines = 0;
    titleLabel.font = [UIFont boldSystemFontOfSize:24.0f];
    titleLabel.text = @"iPad1MailBox\n\nAdd an account with the + button.";
    [welcome.view addSubview:titleLabel];

    UINavigationController *detailNavigation = [[[UINavigationController alloc] initWithRootViewController:welcome] autorelease];

    _splitViewController = [[UISplitViewController alloc] init];
    _splitViewController.viewControllers = [NSArray arrayWithObjects:masterNavigation, detailNavigation, nil];
    _splitViewController.delegate = nil;

    self.window.rootViewController = _splitViewController;
    [self.window makeKeyAndVisible];
    return YES;
}

- (void)applicationDidReceiveMemoryWarning:(UIApplication *)application {
    /* Keep this milestone intentionally light. Network/message caches arrive later. */
}

- (void)dealloc {
    [_splitViewController release];
    [_window release];
    [super dealloc];
}

@end
