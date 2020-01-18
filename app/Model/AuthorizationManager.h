#import <Foundation/Foundation.h>

@interface AuthorizationManager : NSObject

+ (BOOL) createDirectoryAtPath: (NSString*) path;
+ (BOOL) moveFileAtPath: (NSString*) fromPath toPath: (NSString*) toPath;
+ (BOOL) moveFileAtPath: (NSString*) fromPath toPath: (NSString*) toPath asCopy: (bool) asCopy;
+ (BOOL) removeFile: (NSString*) file;
+ (BOOL) moveFolderAtPath: (NSString*) fromPath toPath: (NSString*) toPath;
+ (void) freeAuthorization;

@end
