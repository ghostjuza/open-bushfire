#import "Helper.h"

#import <Foundation/Foundation.h>
#import "Curl.h"
#import "SweeperManager.h"
#import "Settings.h"
#import "Reachability.h"

#include <sys/socket.h>
#include <sys/sysctl.h>
#include <net/if.h>
#include <net/if_dl.h>
#include <syslog.h>
#include <fts.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <stdatomic.h>

typedef struct {
    NSUInteger         count;
    unsigned long long size;
} BFScanResult;

#pragma mark -
#pragma mark Data count and size (off the main thread)

// One category of Safari data (cookies, cache, ...).
// "enabled" is a snapshot of the settings, taken on the calling thread.
//
@interface BFDataCategory : NSObject
@property (nonatomic, copy)   NSString *name;
@property (nonatomic, retain) NSArray  *paths;     // absolute paths, de-duplicated
@property (nonatomic, assign) BOOL      enabled;   // counts as "active"
@end

@implementation BFDataCategory
@synthesize name, paths, enabled;
- (void) dealloc { [name release]; [paths release]; [super dealloc]; }
@end

// Result cache. A category is only stored after a *complete* scan, so a cancelled
// run never leaves half-counted values behind. Toggling a checkbox in the panel
// only changes "enabled", not the scanned data -> answered from cache, no disk I/O.
//
static dispatch_queue_t  bfCacheQueue(void);
static NSMutableDictionary *bfCache(void);          // name -> @{result, date}
static const NSTimeInterval kBFCacheTTL = 3.0;      // seconds

static dispatch_queue_t bfCacheQueue(void)
{
    static dispatch_queue_t q; static dispatch_once_t once;
    dispatch_once(&once, ^{ q = dispatch_queue_create("app.bushfire.DataCountCache", DISPATCH_QUEUE_SERIAL); });
    return q;
}

static NSMutableDictionary *bfCache(void)
{
    static NSMutableDictionary *c; static dispatch_once_t once;
    dispatch_once(&once, ^{ c = [[NSMutableDictionary alloc] init]; });
    return c;
}

// Generation counter: every new async request bumps it, older scans notice and abort.
static _Atomic int64_t bfScanGeneration = 0;

// Fast recursive size/count with fts(3): one pass, no NSString/NSDictionary per file.
// Semantics identical to the old subpathsAtPath + attributesOfItemAtPath code:
//   - the root directory itself is not counted, every entry below it is (files AND dirs)
//   - a plain file counts as 1 object
//   - sizes are st_size (like NSFileSize), symlinks are not followed below the root
// Returns NO if cancelled.
//
static BOOL bfScanPath(NSString *path, BFScanResult *out, BOOL (^isCancelled)(void))
{
    const char *fsPath = path.fileSystemRepresentation;
    if (fsPath == NULL) return YES;
    
    char *paths[2] = { (char*) fsPath, NULL };
    FTS *fts = fts_open(paths, FTS_PHYSICAL | FTS_COMFOLLOW | FTS_NOCHDIR, NULL);
    if (fts == NULL) return YES;
    
    NSUInteger count = 0;
    unsigned long long size = 0;
    unsigned tick = 0;
    BOOL completed = YES;
    FTSENT *e;
    
    while ((e = fts_read(fts)) != NULL) {
        if ((++tick & 0x3FF) == 0 && isCancelled && isCancelled()) { completed = NO; break; }
        
        switch (e->fts_info) {
            case FTS_DP:            // post-order visit of a directory, already seen as FTS_D
                continue;
            case FTS_NS:            // no stat info
            case FTS_ERR:
            case FTS_DC:
                if (e->fts_level > 0) count++;
                continue;
            case FTS_D:
            case FTS_DNR:
                if (e->fts_level == 0) continue;   // root dir is not an object
                break;
            default:
                break;
        }
        count++;
        if (e->fts_statp) size += (unsigned long long) e->fts_statp->st_size;
    }
    
    fts_close(fts);
    
    if (completed) { out->count += count; out->size += size; }
    return completed;
}

// Scans all paths of one category (or serves it from cache).
// Returns NO if cancelled.
//
static BOOL bfScanCategory(BFDataCategory *cat, BOOL useCache, BFScanResult *out, BOOL (^isCancelled)(void))
{
    if (useCache) {
        __block NSDictionary *hit = nil;
        dispatch_sync(bfCacheQueue(), ^{ hit = [[bfCache() objectForKey:cat.name] retain]; });
        if (hit && (-[((NSDate*) hit[@"date"]) timeIntervalSinceNow]) < kBFCacheTTL) {
            out->count = [hit[@"count"] unsignedIntegerValue];
            out->size  = [hit[@"size"] unsignedLongLongValue];
            [hit release];
            return YES;
        }
        [hit release];
    }
    
    BFScanResult r = {0, 0};
    for (NSString *p in cat.paths) {
        if (!bfScanPath(p, &r, isCancelled)) return NO;
    }
    
    NSDictionary *entry = @{ @"count": @(r.count), @"size": @(r.size), @"date": [NSDate date] };
    dispatch_sync(bfCacheQueue(), ^{ [bfCache() setObject:entry forKey:cat.name]; });
    
    *out = r;
    return YES;
}

@implementation Helper

static NSFileManager *fileManager = nil;

+ (void) log:(int)logLevel withMessage:(NSString*)logMessage
{
    if (![[Settings settingsFromDefaults] LogEnabled]) {
        return;
    }
    
    if (@available(macOS 10.14, *)) {
        // @NOTE : maybe better use: syslog_r(LOG_ALERT, syslog_data_struct, "%s", "who:internal error 23");
        syslog(logLevel, "syslog[%d]: %s", logLevel, [logMessage UTF8String]);
    }
    else {
        NSLog(@"nslog[%d]: %@", logLevel, logMessage);
    }
}

+ (bool) isHiddenClearOptionsPressed
{
    NSEvent *currentEvent = [NSApp currentEvent];
    NSUInteger clearFlags = ([currentEvent modifierFlags] & NSEventModifierFlagDeviceIndependentFlagsMask);
    
    return (clearFlags == (NSEventModifierFlagShift | NSEventModifierFlagOption | NSEventModifierFlagCommand));
}

+ (bool) inString:(NSString*)haystack needle:(NSString*)needle
{
    return !([haystack rangeOfString:needle].location == NSNotFound);
}

+ (NSString*) getBundleVersion
{
    return [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"];
}

+ (NSString*) getOSVersionFullVersion
{
    // "Version 10.14.6 (Build 18G2022)"
    return [[NSProcessInfo processInfo] operatingSystemVersionString];
}

+ (NSString*) getOSVersionAsString
{
    // "Version 10.14.6 (Build 18G2022)"
    NSArray *itemList = [[self getOSVersionFullVersion] componentsSeparatedByString:@" "];
    return [itemList objectAtIndex:1];
}

+ (NSString*) getOSBuildAsString
{
    // "Version 10.14.6 (Build 18G2022)"
    NSArray *itemList = [[self getOSVersionFullVersion] componentsSeparatedByString:@" "];
    return [[itemList objectAtIndex:3] stringByReplacingOccurrencesOfString:@")" withString:@""];
}

+ (NSInteger) getOSVersion
{
    NSArray *itemList = [[self getOSVersionFullVersion] componentsSeparatedByString:@" "];
    NSArray *versionItemList = [[itemList objectAtIndex:1] componentsSeparatedByString:@"."];
    
#if DEBUG == 1
    
    [Helper log:LOG_NOTICE withMessage:[NSString stringWithFormat:@"[DBG] macOS Version Raw [%@].", [self getOSVersionFullVersion]]];
    
#endif
    
    NSInteger vMajor = 0;
    NSInteger vRelease = 0;
    NSInteger vFixes = 0;
    
    if ([versionItemList count] == 3) {
        vMajor   = [[versionItemList objectAtIndex:0] integerValue];
        vRelease = [[versionItemList objectAtIndex:1] integerValue];
        vFixes   = [[versionItemList objectAtIndex:2] integerValue];
    }
    else if ([versionItemList count] == 2) {
        vMajor   = [[versionItemList objectAtIndex:0] integerValue];
        vRelease = [[versionItemList objectAtIndex:1] integerValue];
    }
    else {
        vMajor = [[versionItemList objectAtIndex:0] integerValue];
    }
    
    NSString *version = [NSString stringWithFormat:@"%@%@%@",
        [@(vMajor) stringValue],
        (vRelease < 10 ? [NSString stringWithFormat:@"0%@", [@(vRelease) stringValue]] : [@(vRelease) stringValue]),
        (vFixes < 10 ? [NSString stringWithFormat:@"0%@", [@(vFixes) stringValue]] : [@(vFixes) stringValue])
    ];
    NSInteger osVersion = [version integerValue];
    
#if DEBUG == 1
    
    [Helper log:LOG_NOTICE withMessage:[NSString stringWithFormat:@"[DBG] macOS Version as string [%@].", version]];
    [Helper log:LOG_NOTICE withMessage:[NSString stringWithFormat:@"[DBG] macOS Version as int [%@].", [@(osVersion) stringValue]]];
    
#endif
    
    return osVersion;
}


+ (NSFileManager*) getFileManager
{
    //return [NSFileManager defaultManager];
    
    if (fileManager == nil) {
        fileManager = [NSFileManager defaultManager];
    }
    
    return fileManager;
}


+ (NSArray*) appendObjectsFromDirectory:(NSString*)source excludePattern:(nullable NSString*)pattern toArrayList:(NSArray*)arrayList
{
    NSString *absolutePath = [Helper getAbsolutePathWithDirectory:[@"/" stringByAppendingString:source]];
    NSArray  *fileList = [[Helper getFileManager] contentsOfDirectoryAtPath:absolutePath error:nil];
    
    if (fileList) {
        for (int index = 0; index < fileList.count; index++) {
            NSString *file = [fileList objectAtIndex:index];
            if ([pattern isNotEqualTo:nil] && [file rangeOfString:pattern].location != NSNotFound) continue;
            if (file != nil) {
                arrayList = [arrayList arrayByAddingObject:[source stringByAppendingString:file]];
            }
        }
    }
    
    return arrayList;
}


+ (NSDictionary*) dictionaryWithPlist:(NSString *)path
{
    NSError *error;
    NSData * tempData = [NSData dataWithContentsOfFile:path];
    
    if ( tempData == nil ) {
        return [NSDictionary dictionary];
    }
    
    NSPropertyListFormat plistFormat;
    
    return [NSPropertyListSerialization propertyListWithData:tempData options:NSPropertyListImmutable format:&plistFormat error:&error];
}


+ (unsigned long long) spyFinderObjectFromSourceList:(NSArray *)sourceList objectCount:(nullable NSUInteger*)objectCount
{
    unsigned long long objectSizeTotal = 0;
    
    for (int i = 0; i < [sourceList count]; i++) {
        NSUInteger _objectCount = 0;
        NSString *finderPath = [sourceList objectAtIndex:i];
        
        objectSizeTotal += [Helper spyFinderObject:finderPath objectCount:&_objectCount];
        if (objectCount) *objectCount += _objectCount;
    }
    
    return objectSizeTotal;
}


+ (NSString*) getHost
{
    #if LIVE_WWW_HOST == 0
    
        return @"http://127.0.0.1:8000/api/";
    
    #endif
    
    return @"https://www.bushfire.services/api/";
}


+ (int) pushCleanUpCounting:(unsigned long long) cleanupSize cleanupCount:(NSUInteger) cleanupCount
{
    BOOL isConnectionAvailable = [Helper isConnected];
    
    if (!isConnectionAvailable) {
        return 503; // Service Unavailable
    }
    
    NSString *urlParam = [NSString stringWithFormat:@"size=%lu&count=%lu&id=%@&version=%@&build=%@&bundle=%@",
        (unsigned long) cleanupSize,
        (unsigned long) cleanupCount,
        @"6ee589d4988fc5c3a154dc88c60bf721",
        [self getOSVersionAsString],
        [self getOSBuildAsString],
        [self getBundleVersion]
    ];
    NSString *url = [NSString stringWithFormat:@"%@caller/cleanup/counting.php?%@", [Helper getHost], urlParam];
    NSString *response = [Curl call:url withMethod:@"PUT" withBody:NULL];
    
    if ([response isEqualToString:@"200"]) {
        return 200; // Successful
    }
    
    return 400; // Bad request
}

+ (unsigned long long) spyFinderObject:(NSString *)source objectCount:(nullable NSUInteger*)objectCount
{
    unsigned long long objectSize = 0;
    BOOL isDirectory;
    
    if ([[Helper getFileManager] fileExistsAtPath:source isDirectory:&isDirectory])
    {
        if (isDirectory) {
            objectSize = [Helper spyFolder:source objectCount:objectCount];
        }
        else {
            if (objectCount) *objectCount = 1;
            objectSize = [Helper spyFile:source];
        }
    }
    
    return objectSize;
}


+ (unsigned long long) spyFolder:(NSString *)source objectCount:(nullable NSUInteger*)objectCount
{
    BFScanResult r = {0, 0};
    bfScanPath(source, &r, nil);
    if (objectCount) *objectCount = r.count;
    return r.size;
}


+ (unsigned long long) spyFile:(NSString *)source
{
    unsigned long long objectSize = 0;
    BOOL isDirectory;
    
    if ([[Helper getFileManager] fileExistsAtPath:source isDirectory:&isDirectory] && !isDirectory) {
        NSDictionary *fattrs = [[Helper getFileManager] attributesOfItemAtPath:source error:nil];
        objectSize = [[fattrs objectForKey:NSFileSize] unsignedLongLongValue];
    }
    
    return objectSize;
}


+ (NSString*) formatBytes:(unsigned long long)size
{
    NSString *literalText = @"Bytes";
    double dSize = size * 1.0;
    
    if (dSize > 1024) {
        dSize = dSize / 1024.0;
        literalText = @"KB";
        
        if (dSize > 1024) {
            dSize = dSize / 1024.0;
            literalText = @"MB";
            
            if (dSize > 1024) {
                dSize = dSize / 1024.0;
                literalText = @"GB";
                
                if (dSize > 1024) {
                    dSize = dSize / 1024.0;
                    literalText = @"TB";
                }
            }
        }
    }
    
    return [NSString stringWithFormat:@"%.1f %@", (double)dSize, literalText];
}


+ (NSString *)runCommand:(NSString *)commandToRun
{
    NSTask *task = [[NSTask alloc] init];
    [task setLaunchPath:@"/bin/sh"];
    
    NSArray *arguments = [NSArray arrayWithObjects:@"-c", [NSString stringWithFormat:@"%@", commandToRun], nil];
    [task setArguments:arguments];
    
    NSPipe *pipe = [NSPipe pipe];
    [task setStandardOutput:pipe];
    
    NSFileHandle *file = [pipe fileHandleForReading];
    
    [task launch];
    
    NSData   *data   = [file readDataToEndOfFile];
    NSString *output = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    
    return output;
}


+ (NSString *)generateUuidString
{
    CFUUIDRef uuid = CFUUIDCreate(kCFAllocatorDefault);
    NSString *uuidString = (NSString *)CFUUIDCreateString(kCFAllocatorDefault, uuid);
    [uuidString autorelease];
    CFRelease(uuid);
    
    return uuidString;
}


+ (NSString *)getAbsolutePathWithDirectory:(NSString *)path
{
    return [NSString stringWithFormat:@"/Users/%@%@", NSUserName(), path];
}


+ (NSArray*)appendAbsolutePath:(NSArray*)arrayList
{
    NSArray *finderObjectList = [NSArray array];
    
    for (int i = 0; i < [arrayList count]; i++) {
        NSString *item     = [arrayList objectAtIndex:i];
        NSString *fromItem = [@"/" stringByAppendingString:item];
        finderObjectList = [finderObjectList arrayByAddingObject:[Helper getAbsolutePathWithDirectory:fromItem]];
    }
    
    return finderObjectList;
}


+ (bool) restartLaunchAgent:(NSString*)launchAgent logMessage:(NSString*)message
{
    return [Helper restartLaunchAgent:launchAgent logMessage:message unloadOnly:false];
}


+ (bool) restartLaunchAgent:(NSString*)launchAgent logMessage:(NSString*)message unloadOnly:(BOOL)unloadOnly
{
    bool isUnloaded = false;
    bool returnValue = false;
    
    //if ( [Helper getOSVersion] >= 101200 ) {
    if (@available(macOS 10.12, *)) {
        #if DEBUG == 1
        [Helper log:LOG_NOTICE withMessage:@"[DBG] unload via kill ..."];
        #endif
        
        isUnloaded = [Helper runTerminalCommand:
            @"kill -9 `ps aux | grep '/nsurlstoraged' | awk '{print $1, $2, $7}' | grep ' ??' | awk '{print $1, $2}' | grep -v '_nsurlstoraged ' | awk '{print $2}' | tr '\n' ' '`"
            logMessage:message
        ];
        unloadOnly = true;
    }
    else {
        #if DEBUG == 1
        [Helper log:LOG_NOTICE withMessage:@"[DBG] unload via launchctl ..."];
        #endif
        
        isUnloaded = [Helper runTerminalCommand:[@"launchctl unload " stringByAppendingString:launchAgent] logMessage:message];
    }
    
    if (isUnloaded)
    {
        #if DEBUG == 1
        [Helper log:LOG_NOTICE withMessage:@"[DBG] unload success"];
        #endif
        
        if (!unloadOnly && [Helper runTerminalCommand:[@"launchctl load " stringByAppendingString:launchAgent] logMessage:@""]) {
            #if DEBUG == 1
            [Helper log:LOG_NOTICE withMessage:@"[DBG] launchctl load success"];
            #endif
            
            returnValue = true;
        }
        else if (unloadOnly) {
            returnValue = true;
        }
    }
    
    return returnValue;
}


+ (bool) runTerminalCommand:(NSString*)command logMessage:(NSString*)message
{
    if (message.length > 0) {
        [Helper log:LOG_NOTICE withMessage:message];
    }
    
    int retVal = system([command cStringUsingEncoding:NSUTF8StringEncoding]);
    
    // RETURN VALUE [retVal]
    //    The value returned is -1 on  error  (e.g.   fork(2)  failed),  and  the
    //    return  status  of the command otherwise.  This latter return status is
    //    in the format specified in wait(2).  Thus, the exit code of the command
    //    will  be  WEXITSTATUS(status).   In case /bin/sh could not be executed,
    //    the exit status will be that of a command that does exit(127).
    //    
    //    If the value of command is NULL, system() returns non-zero if the shell
    //    is available, and zero if not.
    //
    // -1 is an error. > some error is occured in that shell command
    // 127 is an exception. > That shell command is not found
    //
    // @see http://stackoverflow.com/questions/8941691/how-to-get-the-status-of-command-run-by-system
    //
    if (retVal == -1 || retVal == 127) {
        [Helper log:LOG_ERR withMessage:[NSString stringWithFormat:@"#! command failed [%d].", retVal]];
        return false;
    }
    
#if DEBUG == 1
    
    if (retVal != 0) {
        [Helper log:LOG_NOTICE withMessage:[NSString stringWithFormat:@"[DBG] Shell command return value [%d].", retVal]];
        [Helper log:LOG_NOTICE withMessage:[NSString stringWithFormat:@"[DBG] Shell command [%@].", command]];
    }
    
#endif
    
    return true;
}


+ (void) moveFinderObject:(NSString*)fromSource to:(NSString*)destination
{
    [Helper moveFinderObject:fromSource to:destination asTerminalCommand:false];
}


+ (void) moveFinderObject:(NSString*)fromSource to:(NSString*)destination asTerminalCommand:(bool)asTerminalCommand
{
    if (asTerminalCommand) {
        NSString *_fromItem    = [fromSource stringByReplacingOccurrencesOfString:@" " withString:@"\\ "];
        NSString *_destination = [destination stringByReplacingOccurrencesOfString:@" " withString:@"\\ "];
        
        NSString *cmd = [NSString stringWithFormat:@"mv %@ %@", _fromItem, _destination];
        [Helper runTerminalCommand:cmd logMessage:@""];
    }
    else {
        [[Helper getFileManager] moveItemAtPath:fromSource toPath:destination error:nil];
    }
}


// Builds the category list. Cheap, but touches Settings -> call on the thread that owns it
// (main thread for the UI); the returned objects are immutable snapshots.
//
+ (NSArray*) bf_dataCategoriesForSettings:(Settings*)settings
{
    BOOL on = settings.CleanActive;
    
    struct { NSString *name; NSArray *list; BOOL enabled; } defs[] = {
        { @"CleanForms",        [SweeperManager getFormsList],        on && settings.CleanForms },
        { @"CleanLocation",     [SweeperManager getLocationList],     on && settings.CleanLocation },
        { @"CleanPreview",      [SweeperManager getPreviewList],      on && settings.CleanPreview },
        { @"CleanTopSites",     [SweeperManager getTopSitesList],     on && settings.CleanTopSites },
        { @"CleanCache",        [SweeperManager getCacheList],        on && settings.CleanCache },
        { @"CleanWebPageIcons", [SweeperManager getWebPageIconsList], on && settings.CleanWebPageIcons },
        { @"CleanHistory",      [SweeperManager getHistoryList],      on && settings.CleanHistory },
        { @"CleanDownloads",    [SweeperManager getDownloadsList],    on && settings.CleanDownloads },
        { @"CleanCookies",      [SweeperManager getCookiesList],      on && settings.CleanCookies },
        { @"CleanFlashCookies", [SweeperManager getFlashCookiesList], on && settings.CleanCookies },
        { @"CleanOfflineData",  [SweeperManager getOfflineDataList],  on && settings.CleanOfflineData },
        { @"CleanLocalStorage", [SweeperManager getLocalStorageList], on && settings.CleanOfflineData },
    };
    
    NSMutableArray *result = [NSMutableArray array];
    for (size_t i = 0; i < sizeof(defs) / sizeof(defs[0]); i++) {
        BFDataCategory *cat = [[[BFDataCategory alloc] init] autorelease];
        cat.name    = defs[i].name;
        // de-duplicate (e.g. HistoryIndex.sk is listed twice) so nothing is counted twice
        cat.paths   = [[NSOrderedSet orderedSetWithArray:[Helper appendAbsolutePath:defs[i].list]] array];
        cat.enabled = defs[i].enabled;
        [result addObject:cat];
    }
    return result;
}

+ (void) bf_sumCategories:(NSArray*)categories results:(BFScanResult*)results
    countActive:(NSUInteger*)countActive sizeActive:(unsigned long long*)sizeActive
    countTotal:(NSUInteger*)countTotal sizeTotal:(unsigned long long*)sizeTotal
{
    *countActive = *countTotal = 0;
    *sizeActive  = *sizeTotal  = 0;
    for (NSUInteger i = 0; i < categories.count; i++) {
        *countTotal += results[i].count;
        *sizeTotal  += results[i].size;
        if (((BFDataCategory*) categories[i]).enabled) {
            *countActive += results[i].count;
            *sizeActive  += results[i].size;
        }
    }
}


/**
 Asynchronous variant for the UI. Never blocks the caller.
 - scanning runs on a utility-QoS concurrent queue (categories in parallel)
 - a newer call cancels the older one (no pile-up when the user clicks quickly)
 - completion runs on the main queue and is NOT called for superseded requests
 - useCache:YES answers from a <3 s old scan, e.g. after (un)checking a category
 */
+ (void) detectDataCountAndSizeAsync:(Settings*)settings
    useCache:(BOOL)useCache
    completion:(void (^)(NSUInteger countActive, unsigned long long sizeActive,
                         NSUInteger countTotal, unsigned long long sizeTotal))completion
{
    NSArray *categories = [Helper bf_dataCategoriesForSettings:settings];     // snapshot on caller thread
    const int64_t generation = atomic_fetch_add(&bfScanGeneration, 1) + 1;
    
    BOOL (^isCancelled)(void) = ^BOOL { return atomic_load(&bfScanGeneration) != generation; };
    
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^
    {
        NSUInteger n = categories.count;
        BFScanResult *results = calloc(n, sizeof(BFScanResult));
        __block volatile BOOL aborted = NO;
        
        dispatch_apply(n, dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^(size_t i)
        {
            @autoreleasepool {
                if (aborted || isCancelled()) { aborted = YES; return; }
                if (!bfScanCategory(categories[i], useCache, &results[i], isCancelled)) aborted = YES;
            }
        });
        
        if (!aborted && !isCancelled()) {
            NSUInteger cA, cT; unsigned long long sA, sT;
            [Helper bf_sumCategories:categories results:results countActive:&cA sizeActive:&sA countTotal:&cT sizeTotal:&sT];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                if (!isCancelled()) completion(cA, sA, cT, sT);
            });
        }
        free(results);
    });
}


/**
 Synchronous variant (used by the cleanup in the background, with logging).
 Same engine, no cache, no cancellation, sequential so the log order stays stable.
 MUST NOT be called on the main thread.
 */
+ (void) _detectDataCountAndSize:
    (Settings*)settings
    objectCountCurrent:(nullable NSUInteger*)objectCountCurrent
    objectSizeCurrent:(nullable unsigned long long*)objectSizeCurrent
    objectCountActive:(nullable NSUInteger*)objectCountActive
    objectSizeActive:(nullable unsigned long long*)objectSizeActive
    objectCountTotal:(nullable NSUInteger*)objectCountTotal
    objectSizeTotal:(nullable unsigned long long*)objectSizeTotal
    log:(bool)log
{
    NSUInteger dummyCount = 0; unsigned long long dummySize = 0;
    if (!objectCountCurrent) objectCountCurrent = &dummyCount;
    if (!objectSizeCurrent)  objectSizeCurrent  = &dummySize;
    if (!objectCountActive)  objectCountActive  = &dummyCount;
    if (!objectSizeActive)   objectSizeActive   = &dummySize;
    if (!objectCountTotal)   objectCountTotal   = &dummyCount;
    if (!objectSizeTotal)    objectSizeTotal    = &dummySize;
    
    *objectCountCurrent = *objectCountActive = *objectCountTotal = 0;
    *objectSizeCurrent  = *objectSizeActive  = *objectSizeTotal  = 0;
    
    if (log) {
        [Helper log:LOG_NOTICE withMessage:@"Run detect data count and size"];
    }
    
    for (BFDataCategory *cat in [Helper bf_dataCategoriesForSettings:settings]) {
        BFScanResult r = {0, 0};
        bfScanCategory(cat, NO, &r, nil);
        
        *objectCountCurrent = r.count;
        *objectSizeCurrent  = r.size;
        *objectCountTotal  += r.count;
        *objectSizeTotal   += r.size;
        
        if (cat.enabled) {
            *objectCountActive += r.count;
            *objectSizeActive  += r.size;
        }
        
        if (log) {
            [Helper log:LOG_NOTICE withMessage:[NSString stringWithFormat:@"%@ [objects:%d] [size:%@]",
                cat.name, (int) r.count, [Helper formatBytes:r.size]]];
        }
    }
}


+ (void) detectDataCountAndSizeForPanel:(Settings*)settings targetTextField:(NSTextField*)TfDataCountSize
{
    [Helper detectDataCountAndSizeForPanel:settings targetTextField:TfDataCountSize useCache:NO];
}


+ (void) detectDataCountAndSizeForPanel:(Settings*)settings targetTextField:(NSTextField*)TfDataCountSize useCache:(BOOL)useCache
{
    [TfDataCountSize setStringValue:NSLocalizedString(@"data_count_size_detect", nil)];
    
    [TfDataCountSize retain];   // MRC: keep the label alive until the result arrives
    [Helper detectDataCountAndSizeAsync:settings useCache:useCache completion:^(NSUInteger cA, unsigned long long sA, NSUInteger cT, unsigned long long sT)
    {
        [TfDataCountSize setStringValue:[NSString stringWithFormat:NSLocalizedString(@"data_count_size", nil),
            (int) cA, (int) cT, [Helper formatBytes:sA], [Helper formatBytes:sT]
        ]];
        [TfDataCountSize release];
    }];
}


+ (void) detectAndPushCleanUpCounting:(Settings*)settings
{
    NSUInteger objectCountCurrent = 0;
    unsigned long long objectSizeCurrent = 0;
    NSUInteger objectCountTotal = 0;
    unsigned long long objectSizeTotal = 0;
    NSUInteger objectCountActive = 0;
    unsigned long long objectSizeActive = 0;
    
    [self _detectDataCountAndSize:settings
        objectCountCurrent:&objectCountCurrent
        objectSizeCurrent:&objectSizeCurrent
        objectCountActive:&objectCountActive
        objectSizeActive:&objectSizeActive
        objectCountTotal:&objectCountTotal
        objectSizeTotal:&objectSizeTotal
        log:true
    ];
    
    [Helper log:LOG_NOTICE withMessage:[NSString stringWithFormat:@"Burn %@", [NSString stringWithFormat:@"[objects:%d] [size:%@]", (int) objectCountActive, [Helper formatBytes:objectSizeActive]]]];
    
    #if PUSH_CLEANUP_COUNTING == 1
    
        [Helper log:LOG_NOTICE withMessage:[NSString stringWithFormat:@"Push Cleanup Counting = %@", @"YES"]];
        [Helper pushCleanUpCounting:objectSizeActive cleanupCount:objectCountActive];
    
    #else
    
        [Helper log:LOG_NOTICE withMessage:[NSString stringWithFormat:@"Push Cleanup Counting = %@", @"NO"]];
    
    #endif
}


+ (NSImage*) flippImage:(NSImage*)image withFrame:(NSRect)destRect
{
    [NSGraphicsContext saveGraphicsState];
    NSAffineTransform* xform = [NSAffineTransform transform];
    [xform translateXBy:0.0 yBy:0.0];
    [xform scaleXBy:1.0 yBy:-1.0];
    [xform concat];
    [image drawInRect:NSMakeRect(0, 0, NSWidth(destRect), NSHeight(destRect))]; // Original !!!
    [NSGraphicsContext restoreGraphicsState];
    
    return image;
}


+ (BOOL) isConnected
{
    Reachability *reach = [Reachability reachabilityForInternetConnection];
    NetworkStatus internetStatus = [reach currentReachabilityStatus];
    
    if ((internetStatus != NotReachable)) {
        return YES;
    }
    
    [Helper log:LOG_NOTICE withMessage:@"No internet connection"];
    return NO;
}


/**
 Have to test anstelle AuthorizationExecuteWithPrivileges in AuthorizationManager.m
 */
- (BOOL) runProcessAsAdministrator:(NSString*)scriptPath
    withArguments:(NSArray *)arguments
    output:(NSString **)output
    errorDescription:(NSString **)errorDescription
{
    NSString * allArgs = [arguments componentsJoinedByString:@" "];
    NSString * fullScript = [NSString stringWithFormat:@"'%@' %@", scriptPath, allArgs];

    NSDictionary *errorInfo = [NSDictionary new];
    NSString *script =  [NSString stringWithFormat:@"do shell script \"%@\" with administrator privileges", fullScript];

    NSAppleScript *appleScript = [[NSAppleScript new] initWithSource:script];
    NSAppleEventDescriptor * eventResult = [appleScript executeAndReturnError:&errorInfo];

    // Check errorInfo
    if (! eventResult) {
        // Describe common errors
        *errorDescription = nil;
        if ([errorInfo valueForKey:NSAppleScriptErrorNumber]) {
            NSNumber * errorNumber = (NSNumber *)[errorInfo valueForKey:NSAppleScriptErrorNumber];
            if ([errorNumber intValue] == -128) {
                *errorDescription = @"The administrator password is required to do this.";
            }
        }

        // Set error message from provided message
        if (*errorDescription == nil) {
            if ([errorInfo valueForKey:NSAppleScriptErrorMessage]) {
                *errorDescription = (NSString *)[errorInfo valueForKey:NSAppleScriptErrorMessage];
            }
        }

        return NO;
    }
    else {
        // Set output to the AppleScript's output
        *output = [eventResult stringValue];
        return YES;
    }
}
/* USE example .... https://stackoverflow.com/questions/6841937/authorizationexecutewithprivileges-is-deprecated
NSString * output = nil;
NSString * processErrorDescription = nil;
BOOL success = [self runProcessAsAdministrator:@"/usr/bin/id" withArguments:[NSArray arrayWithObjects:@"-un", nil] output:&output errorDescription:&processErrorDescription];
*/



// https://stackoverflow.com/questions/3696910/return-multiple-objects-from-a-method-in-objective-c

//Add a block to your method:
//
//- (void)myMethodWithMultipleReturnObjectsForObject:(id)object returnBlock:(void (^)(id returnObject1, id returnObject2))returnBlock
//{
//    // do stuff
//
//    returnBlock(returnObject1, returnObject2);
//}

//Then use the method like this:
//
//[myMethodWithMultipleReturnObjectsForObject:object returnBlock:^(id returnObject1, id returnObject2) {
//    // Use the return objects inside the block
//}];

//The return objects in the above example are only usable within the block, so if you want to keep them around for use outside the block, just set some __block vars.
//
//// Keep the objects around for use outside of the block
//__block id object1;
//__block id object2;
//[myMethodWithMultipleReturnObjectsForObject:object returnBlock:^(id returnObject1, id returnObject2) {
//    object1 = returnObject1;
//    object2 = returnObject2;
//}];


@end
