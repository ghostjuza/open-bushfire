#import "Settings.h"

NS_ASSUME_NONNULL_BEGIN

@interface Helper : NSObject

+ (NSString*)getOSVersionFullVersion;
+ (NSInteger)getOSVersion;
+ (bool)isHiddenClearOptionsPressed;
+ (BOOL)isConnected;
+ (NSString*)getHost;

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
+ (NSImage*)flippImage:(NSImage*)image withFrame:(NSRect)destRect;
+ (int)pushCleanUpCounting:(unsigned long long)cleanupSize cleanupCount:(NSUInteger)cleanupCount;
+ (void)detectDataCountAndSize:(Settings*)settings targetTextField:(NSTextField*)TfDataCountSize;
+ (void)detectAndPushCleanUpCounting:(Settings*)settings;

//+ (void) detectDataCountAndSize:(NSArray*)spyList
//    objectCountCurrent:(nullable NSUInteger*)objectCountCurrent
//    objectSizeCurrent:(nullable unsigned long long*)objectSizeCurrent
//    objectCountTotal:(nullable NSUInteger*)objectCountTotal
//    objectSizeTotal:(nullable unsigned long long*)objectSizeTotal
//;



//+ (void) detectDataCountAndSizeForCounting:(Settings*) settings
//    returnBlock:(void (^)(
//        NSUInteger returnObjectCountCurrent,
//        unsigned long long returnObjectSizeCurrent,
//        NSUInteger returnObjectCountTotal,
//        unsigned long long returnObjectSizeTotal,
//        NSUInteger returnObjectCountActive,
//        unsigned long long returnObjectSizeActive
//    )) returnBlock;
//+ (void) detectDataCountAndSizeForCounting:(Settings*) settings
//returnObjectCountCurrent:(nullable NSUInteger*)returnObjectCountCurrent
//returnObjectSizeCurrent:(nullable unsigned long long*)returnObjectSizeCurrent
//returnObjectCountTotal:(nullable NSUInteger*)returnObjectCountTotal
//returnObjectSizeTotal:(nullable unsigned long long*)returnObjectSizeTotal
//returnObjectCountActive:(nullable NSUInteger*)returnObjectCountActive
//                    returnObjectSizeActive:(nullable unsigned long long*)returnObjectSizeActive;

@end

NS_ASSUME_NONNULL_END
