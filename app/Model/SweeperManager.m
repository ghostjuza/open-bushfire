#import "AppDelegate.h"
#import "SweeperManager.h"
#import "Settings.h"
#import "Helper.h"

@interface SweeperManager()

- (BOOL)m_deleteFile:(NSString *)path secure:(BOOL)secure;

@end

@implementation SweeperManager

static NSFileManager *fileManager = nil;
//static NSInteger      osVersion   = 0;

//- (void) detectOSVersion
//{
//    osVersion = [Helper getOSVersion];
//}

- (void) cleanupWithCompletion
{
    [self cleanupWithCompletion:nil];
}

- (void) cleanupWithCompletion:(SweeperManagerBlock)block
{
    //[self detectOSVersion];

    Settings *settings = [Settings settingsFromDefaults];
    NSString *bfQue    = [Helper generateUuidString];
    NSString *quePath  = [@"/tmp/bfrmque." stringByAppendingString:bfQue];

    if (!settings.CleanActive) {
        NSLog(@"Burn is disabled.");
        return;
    }

    if (![self createQueDirectoryForRemove:quePath]) {
        NSLog(@"Create cleanup que failed.");
        return;
    }

    [[AppDelegate getMenubarController] setCleanIcon];

    dispatch_queue_t queue = dispatch_queue_create("app.bushfire.CleanupQueue", NULL);
    dispatch_group_t group = dispatch_group_create();

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        dispatch_group_async(group, queue, ^{
            
            [Helper detectAndPushCleanUpCounting:settings];
            bool burnSecure = settings.CleanSecureActive;

            // Start burn ...
            //
            NSLog(@"Prepare to burn [secure: <%@>]", (burnSecure ? @"YES" : @"NO"));

            // Always try to burn Bushfire junk files !!!
            //
            [self m_moveToQueBushfireJunk:quePath];

            (!settings.CleanForms ?: [self m_moveToQueForms:quePath]);
            (!settings.CleanLocation ?: [self m_moveToQueLocation:quePath]);
            (!settings.CleanWebPageIcons ?: [self m_moveToQueWebPageIcons:quePath]);
            (!settings.CleanHistory ?: [self m_moveToQueHistory:quePath]);
            (!settings.CleanPreview ?: [self m_moveToQuePreview:quePath]);
            (!settings.CleanTopSites ?: [self m_moveToQueTopSites:quePath]);
            (!settings.CleanCache ?: [self m_moveToQueCache:quePath]);
            (!settings.CleanDownloads ?: [self m_moveToQueDownloads:quePath]);
            (!settings.CleanMailDownloads ?: [self m_moveToQueMailDownloads:quePath]);

            // if (settings.CleanReadingList) [self m_moveToQueReadingList];
            // if (settings.CleanRemoteNotifications) [self m_moveToQueRemoteNotifications];
            // if (settings.CleanOfflineData) [self m_moveToQueOfflineData];

            if (settings.CleanCookies)
            {
                [self m_moveToQueCookies:quePath];
                [self m_moveToQueLocalStorage:quePath];
                [self m_moveToQueFlashCookies:quePath];
                //[self m_moveToQueSilverlightCookies:quePath];

                if (settings.CleanZombieCookies) {
                    [self m_restartCookieDemon];
                }
            }

            #if DEBUG == 1

                NSLog(@"[DBG] Burn Que: <%@>", bfQue);

            #endif
            
            // Burn the Q-Folder ...
            //
            [self m_deleteFile:@"/tmp/bfrmque.*" secure:burnSecure];
            
            if (block) {
                block([NSNumber numberWithBool:settings.CleanActive], nil);
            }

            [[AppDelegate getMenubarController] unsetCleanIcon];
        });

        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        dispatch_release(group);
        
        [[AppDelegate getMenubarController] unsetCleanIcon];

    });
}

- (void) restartAgents:(BOOL)forceKillProc
{
    NSString *logMsg = @"";
        
    @try {
        if (forceKillProc)
        {
            NSString *cmd = @"kill -9 `ps -ax | grep -e '/usr/libexec/Safari\\|com\\.apple\\.Safari|Support/cloudd' | awk '{print $1, $2}' | grep -e ' ??' | awk '{print $1}' | tr '\n' ' '`";
            
            #if DEBUG == 1
            
                logMsg = @"[DBG] Try to kill all Safari processes.";
                NSLog(@"[DBG] %@", cmd);
            
            #endif
            
            [Helper runTerminalCommand:cmd logMessage:logMsg];
        }
    }
    @catch (NSException *exception)
    {
        #if DEBUG == 1
        
            NSLog(@"[DBG] %@", exception.reason);
        
        #endif
    }
}

- (BOOL) createQueDirectoryForRemove:(NSString*)quePath
{
    fileManager = [Helper getFileManager];

    NSError *error = nil;
    [fileManager createDirectoryAtPath:quePath withIntermediateDirectories:YES attributes:nil error:&error];

    if (error == nil) {
        return true;
    }

    NSLog(@"Create que directory failed.");
    return false;
}

- (void) moveToQueByArrayList:(NSArray*)arrayList toQuePath:(NSString*)quePath
{
    [self moveToQueByArrayList:arrayList toQuePath:quePath asTerminalCommand:false];
}

- (void) moveToQueByArrayList:(NSArray*)arrayList toQuePath:(NSString*)quePath asTerminalCommand:(bool)asTerminalCommand
{
    for (int i = 0; i < [arrayList count]; i++)
    {
        NSString *item     = [arrayList objectAtIndex:i];
        NSString *fromItem = [@"/" stringByAppendingString:item];
        NSString *toItem   = [self prepareQueName:item];
        
        [Helper moveFinderObject:[Helper getAbsolutePathWithDirectory:fromItem] to:[quePath stringByAppendingPathComponent:toItem] asTerminalCommand:asTerminalCommand];
    }
}

- (NSString*) prepareQueName:(NSString*)path
{
    path = [path stringByReplacingOccurrencesOfString:@"~/" withString:@""];
    path = [path stringByReplacingOccurrencesOfString:@" " withString:@""];
    path = [path stringByReplacingOccurrencesOfString:@"/" withString:@"_"];

    return path;
}

- (BOOL) m_deleteFile:(NSString *)path secure:(BOOL)secure
{
    NSString *logMsg  = @"";
    NSString *command = @"";
    
    if (secure)
    {
        command = [NSString stringWithFormat:@"srm -rfs %@", path];
        
        //if (osVersion >= 101200) {
        if (@available(macOS 10.12, *)) {
            command = [NSString stringWithFormat:@"rm -rdP %@", path];
        }
    }
    else {
        command = [NSString stringWithFormat:@"rm -rd %@", path];
    }

#if DEBUG == 1

    logMsg = [@"[DBG] " stringByAppendingString:command];

#endif
    
    return [Helper runTerminalCommand:command logMessage:logMsg];
}

- (NSMutableDictionary*) _getReadingListNode:(NSMutableDictionary*)completePlist
{
    NSArray *childrens = [completePlist objectForKey:@"Children"];

    for (int i = 0; i < [childrens count]; i++)
    {
        NSMutableDictionary *children = [childrens objectAtIndex:i];
        NSString            *title    = [children objectForKey:@"Title"];

        if ([title isEqualToString:@"com.apple.ReadingList"]) {
            return children;
        }
    }

    return nil;
}

// // Move to Que !!!

- (void) m_moveToQueCookies:(NSString*)quePath
{
    NSArray *arrayList = [SweeperManager getCookiesList];
    [self moveToQueByArrayList:arrayList toQuePath:quePath];
}

+ (NSArray*) getCookiesList
{
    return [NSArray arrayWithObjects:
        @"Library/Cookies/HSTS.plist",
        @"Library/Cookies/com.apple.safari.cookies",
        @"Library/Cookies/com.apple.Safari.SearchHelper.binarycookies",
        @"Library/Cookies/com.apple.Safari.SafeBrowsing.binarycookies",
        @"Library/Cookies/Cookies.plist",
        @"Library/Cookies/Cookies.binarycookies",
        @"Library/Containers/com.apple.Safari/Data/Library/Cookies",
        nil
    ];
}

- (void) m_moveToQueLocalStorage:(NSString*)quePath
{
    NSArray *arrayList = [SweeperManager getLocalStorageList];
    [self moveToQueByArrayList:arrayList toQuePath:quePath];
}

+ (NSArray*) getLocalStorageList
{
    NSArray *arrayList = [NSArray arrayWithObjects:
        @"Library/Safari/LastSession.plist",
        @"Library/Safari/PlugInOrigins.plist",
        @"Library/Safari/PlugInUpdateInfo.plist",
        @"Library/WebKit/com.apple.Safari",
        @"Library/Saved Application State/com.apple.Safari.savedState",
        @"Library/SyncedPreferences/com.apple.Safari.plist",
        nil
    ];
    
    arrayList = [Helper appendObjectsFromDirectory:@"Library/Safari/LocalStorage/" excludePattern:@"safari-extension_" toArrayList:arrayList];
    arrayList = [Helper appendObjectsFromDirectory:@"Library/Safari/Databases/" excludePattern:@"safari-extension_" toArrayList:arrayList];
    
    return arrayList;
}

- (void) m_moveToQueFlashCookies:(NSString*)quePath
{
    NSArray *arrayList = [SweeperManager getFlashCookiesList];
    [self moveToQueByArrayList:arrayList toQuePath:quePath];
}

+ (NSArray*) getFlashCookiesList
{
    return [NSArray arrayWithObjects:
        @"Library/Preferences/Macromedia/Flash Player",
        //@"Library/Preferences/Macromedia/Flash Player/#SharedObjects",
        //@"Library/Preferences/Macromedia/Flash Player/macromedia.com/support/flashplayer/sys",
        nil
    ];
}

- (bool) m_restartCookieDemon
{
    NSString *logMsg = @"";
    
    //if (osVersion >= 101000)
    if (@available(macOS 10.10, *))
    {
        #if DEBUG == 1
        
            logMsg = @"[DBG] Restart nsurlstoraged.";
        
        #endif
        
        return [Helper restartLaunchAgent:@"/System/Library/LaunchAgents/com.apple.nsurlstoraged.plist" logMessage:logMsg];
    }
    else
    {
        #if DEBUG == 1
        
            logMsg = @"[DBG] Restart cookied.";
        
        #endif
        
        return [Helper restartLaunchAgent:@"/System/Library/LaunchAgents/com.apple.cookied.plist" logMessage:logMsg];
    }
}

- (void) m_moveToQueCache:(NSString*)quePath
{
    NSArray *arrayList = [SweeperManager getCacheList];
    [self moveToQueByArrayList:arrayList toQuePath:quePath];
}

+ (NSArray*) getCacheList
{
    return [NSArray arrayWithObjects:
        @"Library/Caches/Metadata/Safari",               // // Remove Metadata Chache of Safari only !!!
        @"Library/Caches/com.apple.Safari",              // // Remove complete Cache Folder
        @"Library/Caches/com.apple.Safari.SocialHelper", // // ...
        @"Library/Caches/com.apple.SafariServices",      // // ...
        @"Library/Caches/com.apple.safaridavclient",     // // Remove Safari DAV Client Folder
        @"Library/Caches/com.apple.Safari.SearchHelper",
        @"Library/Caches/CloudKit/com.apple.Safari",
        @"Library/Caches/Adobe/Flash Player",
        @"Library/Safari/Touch Icons Cache",

        // macOS > 1014
        // Remove complete cache folder from container
        //
        @"Library/Containers/com.apple.Safari/Data/Library/Caches/com.apple.Safari",
        @"Library/Containers/com.apple.Safari/Data/Library/Caches",
        @"Library/Containers/com.apple.Safari.CacheDeleteExtension/Data/Library/Caches",

        nil
    ];
}

- (void) m_moveToQuePreview:(NSString*)quePath
{
    NSArray *arrayList = [SweeperManager getPreviewList];
    [self moveToQueByArrayList:arrayList toQuePath:quePath];
}

+ (NSArray*) getPreviewList
{
    return [NSArray arrayWithObjects:
        @"Library/Caches/com.apple.Safari/Webpage Previews",

        // macOS > 1014
        // Remove complete cache folder from container
        //
        @"Library/Containers/com.apple.Safari.SafariQuickLookPreview/Data/Library/Caches",
        nil
    ];
}

- (void) m_moveToQueHistory:(NSString*)quePath
{
    NSArray *arrayList = [SweeperManager getHistoryList];
    [self moveToQueByArrayList:arrayList toQuePath:quePath];
    
    //[self m_burnCloudHistory];
}

+ (NSArray*) getHistoryList
{
    return [NSArray arrayWithObjects:
        @"Library/Safari/History.db",
        @"Library/Safari/History.db-lock",
        @"Library/Safari/History.db-shm",
        @"Library/Safari/History.db-wal",
        @"Library/Safari/HistoryIndex.sk",
            
        // osVersion < 1010
        @"Library/Safari/History.plist",
        @"Library/Safari/HistoryIndex.sk",
        @"Library/Safari/LastSession.plist",
        
        // macOS > 1012
        @"Library/Safari/RecentlyClosedTabs.plist",
        nil
    ];
}

- (void) m_burnCloudHistory
{
    // Happens automatically on macOS 10.10 and beyond
    //if (osVersion >= 101000) {
    if (@available(macOS 10.10, *)) {
        [Helper restartLaunchAgent:@"/System/Library/LaunchAgents/com.apple.CallHistorySyncHelper.plist" logMessage:@""];
        [Helper restartLaunchAgent:@"/System/Library/LaunchAgents/com.apple.cloudd.plist" logMessage:@""];
    }
}

- (void) m_moveToQueTopSites:(NSString*)quePath
{
    NSArray *arrayList = [SweeperManager getTopSitesList];
    [self moveToQueByArrayList:arrayList toQuePath:quePath];
}

+ (NSArray*) getTopSitesList
{
    return [NSArray arrayWithObjects:
        @"Library/Safari/TopSites.plist",
        nil
    ];
}

- (void) m_moveToQueForms:(NSString*)quePath
{
    NSArray *arrayList = [SweeperManager getFormsList];
    [self moveToQueByArrayList:arrayList toQuePath:quePath];
}

+ (NSArray*) getFormsList
{
    return [NSArray arrayWithObjects:
        @"Library/Safari/Form Values",
        nil
    ];
}

- (void) m_moveToQueDownloads:(NSString*)quePath
{
    NSArray *arrayList = [SweeperManager getDownloadsList];
    [self moveToQueByArrayList:arrayList toQuePath:quePath];
    
    NSString *cmdDeleteFromLaunchService = @"sqlite3 ~/Library/Preferences/com.apple.LaunchServices.QuarantineEventsV* 'delete from LSQuarantineEvent where LSQuarantineAgentBundleIdentifier = \"com.apple.Safari\"'";
    NSString *logMsg = @"";
    
    #if DEBUG == 1
    
        logMsg = @"[DBG] Burn Downlaodlist from hidden DataStorage.";
    
    #endif
    
    [Helper runTerminalCommand:cmdDeleteFromLaunchService logMessage:logMsg];
}

+ (NSArray*) getDownloadsList
{
    NSDictionary *dict = [Helper dictionaryWithPlist:[Helper getAbsolutePathWithDirectory:@"/Library/Safari/Downloads.plist"]];
    NSArray *downloads = [dict objectForKey:@"DownloadHistory"];
    NSArray *arrayList = [NSArray arrayWithObjects:
        @"Library/Safari/Downloads.plist",
        nil
    ];
    
    for (int i = 0; i < downloads.count; i++)
    {
        NSDictionary *download  = [downloads objectAtIndex:i];
        NSString     *entryPath = [download objectForKey:@"DownloadEntryPath"];
        NSString     *path      = [entryPath stringByReplacingOccurrencesOfString:@"~/" withString:@""];
        
        if (path != nil) {
            arrayList = [arrayList arrayByAddingObject:path];
        }
    }
    
    return arrayList;
}

- (void) m_moveToQueMailDownloads:(NSString*)quePath
{
    NSArray *arrayList = [SweeperManager getMailDownloadsList];
    [self moveToQueByArrayList:arrayList toQuePath:quePath];
}

+ (NSArray*) getMailDownloadsList
{
    return [NSArray arrayWithObjects:
        @"Library/Containers/com.apple.mail/Data/Library/Mail Downloads/",
        nil
    ];
}

- (void) m_moveToQueWebPageIcons:(NSString*)quePath
{
    NSArray *arrayList = [SweeperManager getWebPageIconsList];
    [self moveToQueByArrayList:arrayList toQuePath:quePath];
}

+ (NSArray*) getWebPageIconsList
{
    NSArray *arrayList = [NSArray arrayWithObjects:
        @"Library/Safari/WebpageIcons.db",
        @"Library/Safari/Touch Icons",
        @"Library/Safari/Template Icons",
                          
        // [Helper getOSVersion] < 1010
        @"Library/Icons/WebpageIcons.db",
        
        // [Helper getOSVersion] >= 1012
        @"Library/Safari/WebpageIcons.db-shm",
        @"Library/Safari/WebpageIcons.db-wal",

        // [Helper getOSVersion] >= 1014
        @"Library/Safari/Favicon Cache",
        nil
    ];
    
//    if ( [Helper getOSVersion] >= 101400 ) {
//        arrayList = [arrayList arrayByAddingObject:@"",nil];
//    }
    
    return arrayList;
}

- (void) m_moveToQueBushfireJunk:(NSString*)quePath
{
    NSArray *arrayList = [SweeperManager getBushfireJunkList];
    [self moveToQueByArrayList:arrayList toQuePath:quePath];
}

+ (NSArray*) getBushfireJunkList
{
    return [NSArray arrayWithObjects:
        //@"Library/Caches/com.inkoknit.Bushfire",
        @"Library/Cookies/com.inkoknit.Bushfire.binarycookies",
        nil
    ];
}

- (void) m_moveToQueLocation:(NSString*)quePath
{
    NSArray *arrayList = [SweeperManager getLocationList];
    [self moveToQueByArrayList:arrayList toQuePath:quePath];
}

+ (NSArray*) getLocationList
{
    return [NSArray arrayWithObjects:
        @"Library/Safari/LocationPermissions.plist",
        nil
    ];
}

//- (void)m_cleanOfflineData
//{
//    [self m_deleteFile:[self m_absolutePathWithDirectory:@"/Library/Safari/LocalStorage"] secure:NO];
//}

//- (void)m_cleanReadingList
//{
//    NSString *plistFile = [self m_absolutePathWithDirectory:@"/Library/Safari/Bookmarks.plist"];
//
//    NSMutableDictionary *bookmarksPlist  = [NSMutableDictionary dictionaryWithContentsOfFile:plistFile];
//    NSMutableDictionary *readingListDict = [self _getReadingListNode:bookmarksPlist];
//
//    if (readingListDict != nil)
//    {
//        NSArray *childrens = [readingListDict objectForKey:@"Children"];
//
//        if ([childrens count] > 0)
//        {
//            [readingListDict removeObjectForKey:@"Children"];
//            [bookmarksPlist writeToFile:plistFile atomically:YES];
//        }
//    }
//
//    [self m_deleteFile:[self m_absolutePathWithDirectory:@"/Library/Safari/ReadingListArchives/"] secure:NO];
//}

//- (void)m_cleanRemoteNotifications
//{
//    [self m_deleteFile:[self m_absolutePathWithDirectory:@"/Library/Safari/RemoteNotificationss/"] secure:NO];
//    [self m_deleteFile:[self m_absolutePathWithDirectory:@"/Library/Safari/UserNotificationPermissions.plist"] secure:NO];
//}

@end
