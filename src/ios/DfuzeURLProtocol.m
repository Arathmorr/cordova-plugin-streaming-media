#import "StreamingMedia.h"
#import "DfuzeURLProtocol.h"

@implementation  DfuzeURLProtocol

// Define which protocols you want to handle
// In this case, I'm only handling "dfuzeProtocol" manually
// Everything else, (http, https, ftp, etc) is handled by the system
+ (BOOL) canInitWithRequest:(NSURLRequest *)request {
    NSURL* theURL = request.URL;
    NSString* scheme = theURL.scheme;
    if([scheme isEqualToString:@"dfuzeProtocol"]) {
        return YES;
    }
    return NO;
}

// You could modify the request here, but I'm doing my legwork in startLoading
+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request {
    return request;
}

// I'm not doing any custom cache work
+ (BOOL) requestIsCacheEquivalent:(NSURLRequest *)a toRequest:(NSURLRequest *)b {
    return [super requestIsCacheEquivalent:a toRequest:b];
}

// This is where I inject my header
// I take the handled request, add a header, and turn it back into https
// Then I fire it off
- (void) startLoading {
    NSMutableURLRequest* mutableRequest = [self.request mutableCopy];
    [mutableRequest setValue:@"user" forHTTPHeaderField: user];
    [mutableRequest setValue:@"sid" forHTTPHeaderField: sid];

    NSURL* newUrl = [[NSURL alloc] initWithScheme:@"https" host:[mutableRequest.URL host] path:[mutableRequest.URL path]];

    [mutableRequest setURL:newUrl];

    self.connection = [NSURLConnection connectionWithRequest:mutableRequest delegate:self];
}

- (void) stopLoading {
    [self.connection cancel];
}

// Below are boilerplate delegate implementations
// They are responsible for letting our client (the MPMovePlayerController) know what happened

- (void) connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
    [self.client URLProtocol:self didFailWithError:error];
    self.connection = nil;
}

- (void) connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
    [self.client URLProtocol:self didLoadData:data];
}

- (void) connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
    [self.client URLProtocol:self didReceiveResponse:response cacheStoragePolicy:NSURLCacheStorageAllowed];
}

- (void) connectionDidFinishLoading:(NSURLConnection *)connection {
    [self.client URLProtocolDidFinishLoading:self];
