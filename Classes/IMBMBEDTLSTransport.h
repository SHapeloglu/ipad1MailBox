#import <Foundation/Foundation.h>
#include <stdint.h>

extern NSString * const IMBMBEDTLSTransportErrorDomain;

typedef enum {
    IMBMBEDTLSTransportErrorGeneric = 1,
    IMBMBEDTLSTransportErrorTimeout = 2,
    IMBMBEDTLSTransportErrorCancelled = 3,
    IMBMBEDTLSTransportErrorCertificate = 4,
    IMBMBEDTLSTransportErrorClosed = 5
} IMBMBEDTLSTransportErrorCode;

@interface IMBMBEDTLSTransport : NSObject {
    void *_context;
    NSString *_host;
    NSString *_protocolVersion;
    NSString *_cipherSuite;
    BOOL _connected;
    volatile BOOL _cancelled;
}

@property (nonatomic, readonly, getter=isConnected) BOOL connected;
@property (nonatomic, readonly, copy) NSString *host;
@property (nonatomic, readonly, copy) NSString *protocolVersion;
@property (nonatomic, readonly, copy) NSString *cipherSuite;

- (BOOL)connectToHost:(NSString *)host
                 port:(NSUInteger)port
              timeout:(NSTimeInterval)timeout
                error:(NSError **)error;

- (BOOL)writeData:(NSData *)data
          timeout:(NSTimeInterval)timeout
            error:(NSError **)error;

- (NSInteger)readBytes:(uint8_t *)buffer
             maxLength:(NSUInteger)maxLength
               timeout:(NSTimeInterval)timeout
                 error:(NSError **)error;

- (void)cancel;
- (void)close;

@end
