#import <Foundation/Foundation.h>
#import "Curl.h"

//#include <sys/socket.h>
//#include <sys/sysctl.h>
//#include <net/if.h>
//#include <net/if_dl.h>


@implementation Curl


//+ (NSString *) call:(NSString *) url withMethod:(nullable NSString *) method
//{
//    if (method == NULL) {
//        method = @"GET";
//    }
//
//    NSURL *nsUrl = [NSURL URLWithString:url];
//    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:nsUrl];
//    [request setHTTPMethod:method];
//
//    NSError *error = [[NSError alloc] init];
//    NSURLResponse *response;
//
//    NSData *responseData = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
//    NSString *responseString = [[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding];
//
//    return responseString;
//}


+ (NSString *) call:(NSString *) url withMethod:(NSString *) method withBody:(NSString *) body
{
    NSInteger statusCode = 0;
    return [Curl call:url withMethod:method withBody:body statusCode:&statusCode];
}


// Same as above, additionally returns the HTTP status code.
// statusCode == 0 means: no HTTP answer at all (offline, host unreachable, timeout, bad URL).
//
+ (NSString *) call:(NSString *) url withMethod:(NSString *) method withBody:(NSString *) body statusCode:(NSInteger *) statusCode
{
    if (statusCode) *statusCode = 0;
    
    NSURL *nsUrl = [NSURL URLWithString:url];
    if (nsUrl == nil) return nil;
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:nsUrl];
    [request setHTTPMethod:method];
    [request setTimeoutInterval:30];

    if (body != NULL && [body length] > 0) {
        NSData *postData = [body dataUsingEncoding:NSASCIIStringEncoding allowLossyConversion:YES];
        NSString *postLength = [NSString stringWithFormat:@"%lu", (unsigned long) [postData length]];
        
        [request setValue:postLength forHTTPHeaderField:@"Content-Length"];
        [request setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"content-type"];
        [request setHTTPBody:postData];
    }
    
    // The completion handler may run after we stopped waiting (timeout). Therefore:
    //  - the handler owns its own reference of the semaphore (dispatch_retain / dispatch_release),
    //  - results go into a box that the handler's block keeps alive; they are only read after a
    //    successful wait, so a late answer can neither crash nor leak.
    NSMutableDictionary *box = [NSMutableDictionary dictionary];
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    dispatch_retain(semaphore);
    
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        @synchronized (box) {
            if (data) [box setObject:data forKey:@"data"];
            if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
                [box setObject:[NSNumber numberWithInteger:[(NSHTTPURLResponse *) response statusCode]] forKey:@"status"];
            }
        }
        dispatch_semaphore_signal(semaphore);
        dispatch_release(semaphore);
    }];
    [task resume];
    
    long timedOut = dispatch_semaphore_wait(semaphore, dispatch_time(DISPATCH_TIME_NOW, 35 * NSEC_PER_SEC));
    dispatch_release(semaphore);
    
    if (timedOut) {
        [task cancel];
        return nil;
    }
    
    NSData *responseData = nil;
    @synchronized (box) {
        responseData = [[[box objectForKey:@"data"] retain] autorelease];
        if (statusCode) *statusCode = [[box objectForKey:@"status"] integerValue];
    }
    
    if (responseData == nil) return nil;
    
    return [[[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding] autorelease];
}


//+ (NSString*) getDataFromGET : (NSString*) url
//{
//    NSURL *nsUrl = [NSURL URLWithString:url];
//    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:nsUrl];
//    [request setHTTPMethod:@"GET"];
//
//    NSError *error = [[NSError alloc] init];
//    NSURLResponse *response;
//
//    NSData *responseData = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
//    NSString *responseString = [[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding];
//
//    return responseString;
//}
//
//
//+ (NSString*) getDataFromPOST : (NSString*) url withUrlParameter : (NSString*) parameter
//{
//    NSData *postData = [parameter dataUsingEncoding:NSASCIIStringEncoding allowLossyConversion:YES];
//    NSString *postLength = [NSString stringWithFormat:@"%lu", (unsigned long) [postData length]];
//    NSURL *nsUrl = [NSURL URLWithString:url];
//
//    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:nsUrl];
//    [request setHTTPMethod:@"POST"];
//    [request setValue:postLength forHTTPHeaderField:@"Content-Length"];
//    [request setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"content-type"];
//    [request setHTTPBody:postData];
//
//    NSError *error = [[NSError alloc] init];
//    NSHTTPURLResponse *response;
//
//    NSData *responseData = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
//    NSString *responseString = [[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding];
//
//    return responseString;
//}


@end
