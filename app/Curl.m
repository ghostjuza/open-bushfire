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
    NSURL *nsUrl = [NSURL URLWithString:url];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:nsUrl];
    [request setHTTPMethod:method];

    if (body != NULL && [body length] > 0) {
        NSData *postData = [body dataUsingEncoding:NSASCIIStringEncoding allowLossyConversion:YES];
        NSString *postLength = [NSString stringWithFormat:@"%lu", (unsigned long) [postData length]];
        
        [request setValue:postLength forHTTPHeaderField:@"Content-Length"];
        [request setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"content-type"];
        [request setHTTPBody:postData];
    }
    
    NSError *error = [[NSError alloc] init];
    NSHTTPURLResponse *response;

    NSData *responseData = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
    NSString *responseString = [[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding];

    return responseString;
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
