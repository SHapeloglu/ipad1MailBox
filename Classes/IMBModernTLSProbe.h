#import <Foundation/Foundation.h>

@interface IMBModernTLSProbe : NSObject

+ (void)runForHost:(NSString *)host
              port:(NSUInteger)port
            target:(id)target
          selector:(SEL)selector;

@end
