#import <UIKit/UIKit.h>

@interface IMBAppDelegate : NSObject <UIApplicationDelegate> {
    UIWindow *_window;
    UISplitViewController *_splitViewController;
}

@property (nonatomic, retain) UIWindow *window;

@end
