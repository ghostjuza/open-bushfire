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




//    NSString *responseString = [[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding];
//    [responseData release];
//    NSError *error;
//    SBJSON *json = [[SBJSON new] autorelease];
//    NSArray *arrData = [json objectWithString:responseString error:&error];

//+ (nullable NSDictionary*) readFile:(NSString*)file
//{
//    return [self decodeData:[NSData dataWithContentsOfFile:file]];
//}


//NSDictionary *dict;
//NSData *dataFromDict = [NSJSONSerialization dataWithJSONObject:dict
//    options:NSJSONWritingPrettyPrinted
//    error:&error]
//;
//
//NSDictionary *dictFromData = [NSJSONSerialization JSONObjectWithData:dataFromDict
//    options:NSJSONReadingAllowFragments
//    error:&error]
//;


//+ (void) doSomethingWithTheJson:(NSDictionary*)dict
//{
//    //NSDictionary *dict = [self decodeData];
//    NSArray *colours = [dict objectForKey:@"colors"];
//
//    for (NSDictionary *colour in colours) {
//        NSString *name = [colour objectForKey:@"name"];
//        NSLog(@"Colour name: %@", name);
//
//        if ([name isEqualToString:@"green"]) {
//            NSArray *pictures = [colour objectForKey:@"pictures"];
//            for (NSDictionary *picture in pictures) {
//                NSString *pictureName = [picture objectForKey:@"name"];
//                NSLog(@"Picture name: %@", pictureName);
//            }
//        }
//    }
//}

@end
