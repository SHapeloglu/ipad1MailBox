#import <Foundation/Foundation.h>

@interface IMBRFC2047Decoder : NSObject

+ (NSString *)decodeHeaderValue:(NSString *)value;

@end
