
//typedef enum {
//    POST = @"POST",
//    GET = @"GET"
//} HttpMethod;

@interface Curl : NSObject

+ (NSString *) call:(NSString *) url withMethod:(NSString *) method withBody:(NSString *) body;
+ (NSString *) call:(NSString *) url withMethod:(NSString *) method withBody:(NSString *) body statusCode:(NSInteger *) statusCode;

@end
