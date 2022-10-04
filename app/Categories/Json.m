#import "Json.h"

#import <Foundation/Foundation.h>
#import "Helper.h"
#import "syslog.h"

@implementation Json

+ (nullable NSDictionary*) decode:(NSString*)json
{
    NSError* error;
    NSData* jsonData = [json dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary* dict = [NSJSONSerialization JSONObjectWithData:jsonData options:NSJSONReadingMutableContainers error:&error];
    if (dict == nil) {
        [Helper log:LOG_ERR withMessage:[NSString stringWithFormat:@"%@", error]];
    }
    return dict;
}

+ (nullable NSDictionary*) decodeData:(nullable NSData*)jsonData
{
    if (jsonData == nil) {
        return nil;
    }
    NSError* error;
    NSDictionary* dict = [NSJSONSerialization JSONObjectWithData:jsonData options:kNilOptions error:&error];
    if (dict == nil) {
        [Helper log:LOG_ERR withMessage:[NSString stringWithFormat:@"%@", error]];
    }
    return dict;
}

+ (nullable NSDictionary*) decodeFile:(NSString*)file
{
    return [self decodeData:[NSData dataWithContentsOfFile:file]];
}

+ (nullable NSDictionary*) decodeBundle:(NSString*)pathForResource
{
    return [self decodeData:[NSData dataWithContentsOfFile:[[NSBundle mainBundle] pathForResource:pathForResource ofType:@"json"]]];
}


+ (nullable NSString*) encode:(nullable NSDictionary*)dict
{
    if (dict == nil) {
        return nil;
    }
    NSData* jsonData = [self encodeData:dict];
    if (jsonData == nil) return nil;
    NSString* json = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    [jsonData release];
    return json;
}

+ (nullable NSData*) encodeData:(nullable NSDictionary*)dict
{
    //    return [NSKeyedArchiver archivedDataWithRootObject:dict];
    if (dict == nil) {
        return nil;
    }
    NSError* error;
    NSData* jsonData = [NSJSONSerialization dataWithJSONObject:dict options:NSJSONWritingPrettyPrinted error:&error];
    if (jsonData == nil) {
        [Helper log:LOG_ERR withMessage:[NSString stringWithFormat:@"%@", error]];
    }
    return jsonData;
}

@end
