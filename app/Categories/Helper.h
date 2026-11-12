#import "Settings.h"

NS_ASSUME_NONNULL_BEGIN

@interface Helper : NSObject

+ (NSString*)getBundleVersion;
+ (NSString*)getOSVersionFullVersion;
+ (NSString*)getOSVersionAsString;
+ (NSString*)getOSBuildAsString;
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
+ (NSString*)formatCount:(NSUInteger)count;
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
+ (void)flushPendingCleanupPushes;
+ (void)detectDataCountAndSizeForPanel:(Settings*)settings targetTextField:(NSTextField*)TfDataCountSize;
+ (void)detectDataCountAndSizeForPanel:(Settings*)settings targetTextField:(NSTextField*)TfDataCountSize useCache:(BOOL)useCache;
+ (void)detectDataCountAndSizeAsync:(Settings*)settings useCache:(BOOL)useCache completion:(void (^)(NSUInteger countActive, unsigned long long sizeActive, NSUInteger countTotal, unsigned long long sizeTotal, NSDictionary *byCategory))completion;
+ (void)detectDataCountAndSizeForPanel:(Settings*)settings targetTextField:(NSTextField*)TfDataCountSize useCache:(BOOL)useCache perCategory:(nullable void (^)(NSDictionary *byCategory))perCategory;
+ (void)detectAndPushCleanUpCounting:(Settings*)settings;

/**
 logLevel :: Specifies the part of the system generating the message, and as a level, indicates the severity of the message. The level of severity is selected from the following list:
 LOG_ALERT   : Indicates a condition that should be corrected immediately; for example, a corrupted database.
 LOG_CRIT    : Indicates critical conditions; for example, hard device errors.
 LOG_DEBUG   : Displays messages containing information useful to debug a program.
 LOG_EMERG   : Indicates a panic condition reported to all users; system is unusable.
 LOG_ERR     : Indicated error conditions.
 LOG_INFO    : Indicates general information messages.
 LOG_NOTICE  : Indicates a condition requiring special handling, but not an error condition.
 LOG_WARNING : Logs warning messages.
 
 @param logLevel LOG_ALERT, LOG_CRIT, ...
 @param logMessage the message to log
 */
+ (void)log:(int)logLevel withMessage:(NSString*)logMessage;


+ (bool)inString:(NSString*)haystack needle:(NSString*)needle;

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
