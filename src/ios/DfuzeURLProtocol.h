@interface DfuzeURLProtocol : NSURLProtocol <NSURLConnectionDelegate, NSURLConnectionDataDelegate>

@property (nonatomic, strong) NSURLConnection* connection;

@end