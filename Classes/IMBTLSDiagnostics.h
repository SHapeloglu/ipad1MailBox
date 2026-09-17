#import <Foundation/Foundation.h>

@interface IMBTLSDiagnostics : NSObject

+ (NSString *)diagnosticReportForHost:(NSString *)host port:(NSUInteger)port;

@end
