#import "Settings.h"

NS_ASSUME_NONNULL_BEGIN

@interface Helper : NSObject

+ (NSString*)getOSVersionFullVersion;
+ (NSInteger)getOSVersion;
+ (bool)isHiddenClearOptionsPressed;
+ (BOOL)isConnected;
+ (NSFileManager*)getFileManager;
+ (NSDictionary*)dictionaryWithPlist:(NSString*)path;
+ (NSArray*)appendObjectsFromDirectory:(NSString*)source excludePattern:(nullable NSString*)pattern toArrayList:(NSArray*)arrayList;
+ (unsigned long long)spyFinderObjectFromSourceList:(NSArray *)sourceList objectCount:(nullable NSUInteger*)objectCount;
+ (unsigned long long)spyFinderObject:(NSString*)source objectCount:(nullable NSUInteger*)objectCount;
+ (unsigned long long)spyFolder:(NSString *)source objectCount:(nullable NSUInteger*)objectCount;
+ (unsigned long long)spyFile:(NSString*)source;
+ (NSString*)formatBytes:(unsigned long long)size;
+ (NSString*)runCommand:(NSString*)commandToRun;
+ (NSString*)generateUuidString;
+ (NSString*)getAbsolutePathWithDirectory:(NSString*)path;
+ (NSArray*)appendAbsolutePath:(NSArray*)arrayList;
+ (bool)restartLaunchAgent:(NSString*)launchAgent logMessage:(NSString*)message;
+ (bool)restartLaunchAgent:(NSString*)launchAgent logMessage:(NSString*)message unloadOnly:(BOOL)unloadOnly;
+ (bool)runTerminalCommand:(NSString*)command logMessage:(NSString*)message;
+ (void)moveFinderObject:(NSString*)fromSource to:(NSString*)destination;
+ (void)moveFinderObject:(NSString*)fromSource to:(NSString*)destination asTerminalCommand:(bool)asTerminalCommand;
+ (void)detectDataCountAndSize:(Settings*)settings targetTextField:(NSTextField*)TfDataCountSize;
+ (NSImage*)flippImage:(NSImage*)image withFrame:(NSRect)destRect;
+ (void) detectDataCountAndSize:(NSArray*)spyList
    objectCountCurrent:(nullable NSUInteger*)objectCountCurrent
    objectSizeCurrent:(nullable unsigned long long*)objectSizeCurrent
    objectCountTotal:(nullable NSUInteger*)objectCountTotal
    objectSizeTotal:(nullable unsigned long long*)objectSizeTotal
;
@end

NS_ASSUME_NONNULL_END
