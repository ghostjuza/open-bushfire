#import <Foundation/Foundation.h>
#import "Helper.h"
#import "Curl.h"
#import "SweeperManager.h"
#import "Settings.h"
#import "Reachability.h"

#include <sys/socket.h>
#include <sys/sysctl.h>
#include <net/if.h>
#include <net/if_dl.h>

@implementation Helper

static NSFileManager *fileManager = nil;

+ (bool) isHiddenClearOptionsPressed
{
    NSEvent *currentEvent = [NSApp currentEvent];
    NSUInteger clearFlags = ([currentEvent modifierFlags] & NSDeviceIndependentModifierFlagsMask);
    
    return (clearFlags == (NSShiftKeyMask | NSAlternateKeyMask | NSCommandKeyMask));
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
    
    NSLog(@"[DBG] macOS Version Raw [%@].", [self getOSVersionFullVersion]);
    
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
    
    NSLog(@"[DBG] macOS Version as string [%@].", version);
    NSLog(@"[DBG] macOS Version as int [%@].", [@(osVersion) stringValue]);
    
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
    NSArray  *fileList     = [[Helper getFileManager] contentsOfDirectoryAtPath:absolutePath error:nil]; 
    
    if (fileList) 
    {
        for (int index = 0; index < fileList.count; index++)
        {
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
    
    for (int i = 0; i < [sourceList count]; i++)
    {
        NSUInteger _objectCount = 0;
        NSString *finderPath = [sourceList objectAtIndex:i];
        
        objectSizeTotal += [Helper spyFinderObject:finderPath objectCount:&_objectCount];
        *objectCount += _objectCount;
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
            *objectCount = 1;
            objectSize = [Helper spyFile:source];
        }
    }
    
    return objectSize;
}


+ (unsigned long long) spyFolder:(NSString *)source objectCount:(nullable NSUInteger*)objectCount
{
    NSArray      *contents;
    NSEnumerator *enumerator;
    NSString     *path;
    
    unsigned long long objectSize = 0;
    BOOL isDirectory;
    
    if ([[Helper getFileManager] fileExistsAtPath:source isDirectory:&isDirectory] && isDirectory) {
        contents = [[NSFileManager defaultManager] subpathsAtPath:source];
    }
    else {
        contents = [NSArray array];
    }
    
    // Add Size Of All Paths 
    enumerator = [contents objectEnumerator];
    
    while (path = [enumerator nextObject])
    {
        NSDictionary *fattrs = [[Helper getFileManager] attributesOfItemAtPath:[source stringByAppendingPathComponent:path] error:nil];
        objectSize += [[fattrs objectForKey:NSFileSize] unsignedLongLongValue];
    }
    
    *objectCount = [contents count];
    
    return objectSize;
}


+ (unsigned long long) spyFile:(NSString *)source
{
    unsigned long long objectSize = 0;
    BOOL isDirectory;
    
    if ([[Helper getFileManager] fileExistsAtPath:source isDirectory:&isDirectory] && !isDirectory)
    {
        NSDictionary *fattrs = [[Helper getFileManager] attributesOfItemAtPath:source error:nil];
        objectSize = [[fattrs objectForKey:NSFileSize] unsignedLongLongValue];
    }
    
    return objectSize;
}


+ (NSString*) formatBytes:(unsigned long long)size
{
    NSString *literalText = @"Bytes";
    double dSize = size * 1.0;
    
    if (dSize > 1024)
    {
        dSize = dSize / 1024.0;
        literalText = @"KB";
        
        if (dSize > 1024)
        {
            dSize = dSize / 1024.0;
            literalText = @"MB";
            
            if (dSize > 1024)
            {
                dSize = dSize / 1024.0;
                literalText = @"GB";
                
                if (dSize > 1024)
                {
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
    //NSLog(@"run command:%@", commandToRun);
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
    
    for (int i = 0; i < [arrayList count]; i++)
    {
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
                NSLog(@"[DBG] %@", @"unload via kill ...");
        #endif
        
        isUnloaded = [Helper runTerminalCommand:
            @"kill -9 `ps aux | grep '/nsurlstoraged' | awk '{print $1, $2, $7}' | grep ' ??' | awk '{print $1, $2}' | grep -v '_nsurlstoraged ' | awk '{print $2}' | tr '\n' ' '`"
            logMessage:message
        ];
    }
    else {
        #if DEBUG == 1
                NSLog(@"[DBG] %@", @"unload via launchctl ...");
        #endif
        
        isUnloaded = [Helper runTerminalCommand:[@"launchctl unload " stringByAppendingString:launchAgent] logMessage:message];
    }
    
    if (isUnloaded)
    {
        #if DEBUG == 1
                NSLog(@"[DBG] %@", @"unload success");
        #endif
        
        if (!unloadOnly && [Helper runTerminalCommand:[@"launchctl load " stringByAppendingString:launchAgent] logMessage:@""]) {
            #if DEBUG == 1
                NSLog(@"[DBG] %@", @"launchctl load success");
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
        NSLog(@"%@", message);
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
    if (retVal == -1 || retVal == 127)
    {
        NSLog(@"#! command failed [%d].", retVal);
        return false;
    }
    
#if DEBUG == 1
    
    if (retVal != 0)
    {
        NSLog(@"[DBG] Shell command return value [%d].", retVal);
        NSLog(@"[DBG] Shell command [%@].", command);
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
    if (asTerminalCommand)
    {
        NSString *_fromItem    = [fromSource stringByReplacingOccurrencesOfString:@" " withString:@"\\ "];
        NSString *_destination = [destination stringByReplacingOccurrencesOfString:@" " withString:@"\\ "];
        
        NSString *cmd = [NSString stringWithFormat:@"mv %@ %@", _fromItem, _destination];
        [Helper runTerminalCommand:cmd logMessage:@""];
    }
    else {
        [[Helper getFileManager] moveItemAtPath:fromSource toPath:destination error:nil];
    }
}


+ (void) _detectDataCountAndSize:
    (Settings*)settings
    objectCountCurrent:(nullable NSUInteger*)objectCountCurrent
    objectSizeCurrent:(nullable unsigned long long*)objectSizeCurrent
    objectCountActive:(nullable NSUInteger*)objectCountActive
    objectSizeActive:(nullable unsigned long long*)objectSizeActive
    objectCountTotal:(nullable NSUInteger*)objectCountTotal
    objectSizeTotal:(nullable unsigned long long*)objectSizeTotal
{
    *objectCountCurrent = 0;
    *objectSizeCurrent = 0;
    *objectCountTotal = 0;
    *objectSizeTotal = 0;
    *objectCountActive = 0;
    *objectSizeActive = 0;
    
    [self detectDataCountAndSize:[Helper appendAbsolutePath:[SweeperManager getFormsList]]
        objectCountCurrent:&*objectCountCurrent objectSizeCurrent:&*objectSizeCurrent objectCountTotal:&*objectCountTotal objectSizeTotal:&*objectSizeTotal
    ];
    if (settings.CleanActive && settings.CleanForms) {
        *objectSizeActive  += *objectSizeCurrent;
        *objectCountActive += *objectCountCurrent;
    }

    [self detectDataCountAndSize:[Helper appendAbsolutePath:[SweeperManager getLocationList]]
        objectCountCurrent:&*objectCountCurrent objectSizeCurrent:&*objectSizeCurrent objectCountTotal:&*objectCountTotal objectSizeTotal:&*objectSizeTotal
    ];
    if (settings.CleanActive && settings.CleanLocation) {
        *objectSizeActive  += *objectSizeCurrent;
        *objectCountActive += *objectCountCurrent;
    }
    
    [self detectDataCountAndSize:[Helper appendAbsolutePath:[SweeperManager getWebPageIconsList]]
        objectCountCurrent:&*objectCountCurrent objectSizeCurrent:&*objectSizeCurrent objectCountTotal:&*objectCountTotal objectSizeTotal:&*objectSizeTotal
    ];
    if (settings.CleanActive && settings.CleanWebPageIcons) {
        *objectSizeActive  += *objectSizeCurrent;
        *objectCountActive += *objectCountCurrent;
    }
    
    [self detectDataCountAndSize:[Helper appendAbsolutePath:[SweeperManager getHistoryList]]
        objectCountCurrent:&*objectCountCurrent objectSizeCurrent:&*objectSizeCurrent objectCountTotal:&*objectCountTotal objectSizeTotal:&*objectSizeTotal
    ];
    if (settings.CleanActive && settings.CleanHistory) {
        *objectSizeActive  += *objectSizeCurrent;
        *objectCountActive += *objectCountCurrent;
    }
    
    [self detectDataCountAndSize:[Helper appendAbsolutePath:[SweeperManager getPreviewList]]
        objectCountCurrent:&*objectCountCurrent objectSizeCurrent:&*objectSizeCurrent objectCountTotal:&*objectCountTotal objectSizeTotal:&*objectSizeTotal
    ];
    if (settings.CleanActive && settings.CleanPreview) {
        *objectSizeActive  += *objectSizeCurrent;
        *objectCountActive += *objectCountCurrent;
    }
    
    [self detectDataCountAndSize:[Helper appendAbsolutePath:[SweeperManager getTopSitesList]]
        objectCountCurrent:&*objectCountCurrent objectSizeCurrent:&*objectSizeCurrent objectCountTotal:&*objectCountTotal objectSizeTotal:&*objectSizeTotal
    ];
    if (settings.CleanActive && settings.CleanTopSites) {
        *objectSizeActive  += *objectSizeCurrent;
        *objectCountActive += *objectCountCurrent;
    }
    
    [self detectDataCountAndSize:[Helper appendAbsolutePath:[SweeperManager getCacheList]]
        objectCountCurrent:&*objectCountCurrent objectSizeCurrent:&*objectSizeCurrent objectCountTotal:&*objectCountTotal objectSizeTotal:&*objectSizeTotal
    ];
    if (settings.CleanActive && settings.CleanCache) {
        *objectSizeActive  += *objectSizeCurrent;
        *objectCountActive += *objectCountCurrent;
    }
    
    [self detectDataCountAndSize:[Helper appendAbsolutePath:[SweeperManager getDownloadsList]]
        objectCountCurrent:&*objectCountCurrent objectSizeCurrent:&*objectSizeCurrent objectCountTotal:&*objectCountTotal objectSizeTotal:&*objectSizeTotal
    ];
    if (settings.CleanActive && settings.CleanDownloads) {
        *objectSizeActive  += *objectSizeCurrent;
        *objectCountActive += *objectCountCurrent;
    }
    
    [self detectDataCountAndSize:[Helper appendAbsolutePath:[SweeperManager getCookiesList]]
        objectCountCurrent:&*objectCountCurrent objectSizeCurrent:&*objectSizeCurrent objectCountTotal:&*objectCountTotal objectSizeTotal:&*objectSizeTotal
    ];
    if (settings.CleanActive && settings.CleanCookies) {
        *objectSizeActive  += *objectSizeCurrent;
        *objectCountActive += *objectCountCurrent;
    }
    
    [self detectDataCountAndSize:[Helper appendAbsolutePath:[SweeperManager getLocalStorageList]]
        objectCountCurrent:&*objectCountCurrent objectSizeCurrent:&*objectSizeCurrent objectCountTotal:&*objectCountTotal objectSizeTotal:&*objectSizeTotal
    ];
    if (settings.CleanActive && settings.CleanCookies) {
        *objectSizeActive  += *objectSizeCurrent;
        *objectCountActive += *objectCountCurrent;
    }
    
    [self detectDataCountAndSize:[Helper appendAbsolutePath:[SweeperManager getFlashCookiesList]]
        objectCountCurrent:&*objectCountCurrent objectSizeCurrent:&*objectSizeCurrent objectCountTotal:&*objectCountTotal objectSizeTotal:&*objectSizeTotal
    ];
    if (settings.CleanActive && settings.CleanCookies) {
        *objectSizeActive  += *objectSizeCurrent;
        *objectCountActive += *objectCountCurrent;
    }
}


+ (void) detectDataCountAndSize:(NSArray*)spyList
    objectCountCurrent:(nullable NSUInteger*)objectCountCurrent
    objectSizeCurrent:(nullable unsigned long long*)objectSizeCurrent
    objectCountTotal:(nullable NSUInteger*)objectCountTotal
    objectSizeTotal:(nullable unsigned long long*)objectSizeTotal
{
    NSUInteger countCurrent = 0;
    unsigned long long sizeCurrent = [Helper spyFinderObjectFromSourceList:spyList objectCount:&countCurrent];
    
    *objectCountCurrent = countCurrent;
    *objectSizeCurrent = sizeCurrent;
    
    *objectCountTotal += countCurrent;
    *objectSizeTotal += sizeCurrent;
}


+ (void) detectDataCountAndSize:(Settings*)settings targetTextField:(NSTextField*)TfDataCountSize
{
    [TfDataCountSize setStringValue:NSLocalizedString(@"data_count_size_detect", nil)];

    __block NSUInteger objectCountCurrent = 0;
    __block unsigned long long objectSizeCurrent = 0;
    __block NSUInteger objectCountTotal = 0;
    __block unsigned long long objectSizeTotal = 0;
    __block NSUInteger objectCountActive = 0;
    __block unsigned long long objectSizeActive = 0;

    dispatch_async(dispatch_get_main_queue(), ^
    {
        [self _detectDataCountAndSize:settings
             objectCountCurrent:&objectCountCurrent
             objectSizeCurrent:&objectSizeCurrent
             objectCountActive:&objectCountActive
             objectSizeActive:&objectSizeActive
             objectCountTotal:&objectCountTotal
             objectSizeTotal:&objectSizeTotal
        ];
        
        NSString *dataCountAndSize = [NSString stringWithFormat:NSLocalizedString(@"data_count_size", nil),
            (int) objectCountActive, (int) objectCountTotal, [Helper formatBytes:objectSizeActive], [Helper formatBytes:objectSizeTotal]
        ];
        [TfDataCountSize setStringValue:dataCountAndSize];
    });
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
    ];
    
    NSLog(@"Burn [%@]", [NSString stringWithFormat:@"Objects <%d>, Size <%@>", (int) objectCountActive, [Helper formatBytes:objectSizeActive]]);
    
    #if PUSH_CLEANUP_COUNTING == 1
    
        NSLog(@"Push Cleanup Counting <%@>", @"YES");
        [Helper pushCleanUpCounting:objectSizeActive cleanupCount:objectCountActive];
    
    #else
    
        NSLog(@"Push Cleanup Counting <%@>", @"NO");
    
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
    
    NSLog(@"%@", @"No internet connection");
    return NO;
}


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
