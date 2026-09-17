#import <UIKit/UIKit.h>
#import "Classes/IMBAppDelegate.h"

int main(int argc, char *argv[]) {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    int retVal = UIApplicationMain(argc, argv, nil, @"IMBAppDelegate");
    [pool release];
    return retVal;
}
