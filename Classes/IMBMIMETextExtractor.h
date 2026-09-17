#import <Foundation/Foundation.h>

@interface IMBMIMETextExtractor : NSObject

/* Extract the first non-attachment text/plain MIME entity from a raw RFC 822
 * message. The caller is expected to provide a bounded message prefix fetched
 * from IMAP so memory use remains predictable on the original iPad.
 */
+ (NSString *)plainTextFromMessageData:(NSData *)messageData;

@end
