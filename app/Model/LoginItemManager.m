#import "LoginItemManager.h"

@implementation LoginItemManager

+ (void)enableLoginItemWithLoginItemsReference:(LSSharedFileListRef )theLoginItemsRefs ForPath:(NSString *)appPath
{
	CFURLRef url = (CFURLRef)[NSURL fileURLWithPath:appPath];
    
	LSSharedFileListItemRef item = LSSharedFileListInsertItemURL(
        theLoginItemsRefs,
        kLSSharedFileListItemLast,
        NULL,
        NULL,
        url,
        NULL,
        NULL
    );
    
	if ( item ) {
		CFRelease(item);
    }
}

+ (void)disableLoginItemWithLoginItemsReference:(LSSharedFileListRef )theLoginItemsRefs ForPath:(NSString *)appPath
{
    UInt32 seedValue;
	CFURLRef thePath = NULL;
    CFArrayRef loginItemsArray = LSSharedFileListCopySnapshot(theLoginItemsRefs, &seedValue);
	
    for ( id item in (NSArray *)loginItemsArray )
    {
		LSSharedFileListItemRef itemRef = (LSSharedFileListItemRef)item;
		
        if ( LSSharedFileListItemResolve(itemRef, 0, (CFURLRef*) &thePath, NULL) == noErr ) {
		
            if ( [[(NSURL *)thePath path] hasPrefix:appPath] ) {
				LSSharedFileListItemRemove(theLoginItemsRefs, itemRef); // Deleting the item
			}

            if ( thePath != NULL ) {
               CFRelease(thePath); 
            }
		}		
	}
	
	if ( loginItemsArray != NULL ) {
        CFRelease(loginItemsArray); 
    }
}

+ (BOOL)loginItemExistsWithLoginItemReference:(LSSharedFileListRef)theLoginItemsRefs ForPath:(NSString *)appPath
{
    BOOL found = NO;  
	UInt32 seedValue;
	CFURLRef thePath = NULL;
	CFArrayRef loginItemsArray = LSSharedFileListCopySnapshot(theLoginItemsRefs, &seedValue);
	
    for ( id item in (NSArray *)loginItemsArray ) {    
		LSSharedFileListItemRef itemRef = (LSSharedFileListItemRef)item;
		
        if ( LSSharedFileListItemResolve(itemRef, 0, (CFURLRef*) &thePath, NULL) == noErr ) {
			
            if ( [[(NSURL *)thePath path] hasPrefix:appPath] ) {
				found = YES;
				break;
			}
            
            if ( thePath != NULL ) {
                CFRelease(thePath);
            }
		}
	}
    
	if ( loginItemsArray != NULL ) {
       CFRelease(loginItemsArray); 
    }
	
	return found;
}

// Autostart ueber LaunchAgent in ~/Library/LaunchAgents (zuverlaessig unter macOS 11+,
// die alte LSSharedFileList-Anmeldeobjektliste liefert dort unbrauchbare Ergebnisse).
+ (NSString *)launchAgentPath
{
    NSString *label = [[NSBundle mainBundle] bundleIdentifier];
    if ([label length] == 0) label = @"de.bushfire.app";
    NSString *dir = [NSHomeDirectory() stringByAppendingPathComponent:@"Library/LaunchAgents"];
    return [dir stringByAppendingPathComponent:[label stringByAppendingString:@".autostart.plist"]];
}

+ (BOOL)isLaunchAtStartup
{
    return [[NSFileManager defaultManager] fileExistsAtPath:[self launchAgentPath]];
}

+ (void)toggleLaunchAtStartup
{
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *path = [self launchAgentPath];
    
    if ([fm fileExistsAtPath:path]) {
        NSError *error = nil;
        if (![fm removeItemAtPath:path error:&error]) NSLog(@"Bushfire: Autostart entfernen fehlgeschlagen: %@", error);
        return;
    }
    
    NSString *label = [[path lastPathComponent] stringByDeletingPathExtension];
    NSDictionary *plist = [NSDictionary dictionaryWithObjectsAndKeys:
        label, @"Label",
        [NSArray arrayWithObjects:@"/usr/bin/open", @"-a", [[NSBundle mainBundle] bundlePath], nil], @"ProgramArguments",
        [NSNumber numberWithBool:YES], @"RunAtLoad",
        nil];
    
    NSError *error = nil;
    [fm createDirectoryAtPath:[path stringByDeletingLastPathComponent] withIntermediateDirectories:YES attributes:nil error:&error];
    if (![plist writeToFile:path atomically:YES]) NSLog(@"Bushfire: Autostart schreiben fehlgeschlagen: %@", path);
}

+ (LSSharedFileListItemRef)itemRefInLoginItems
{
    LSSharedFileListItemRef itemRef = nil;
    NSURL *itemUrl = nil;
    NSURL *appUrl = [NSURL fileURLWithPath:[[NSBundle mainBundle] bundlePath]];
    LSSharedFileListRef loginItemsRef = LSSharedFileListCreate(NULL, kLSSharedFileListSessionLoginItems, NULL);
    
    if (loginItemsRef == nil) return nil;
    
    NSArray *loginItems = (NSArray *)LSSharedFileListCopySnapshot(loginItemsRef, nil);
    
    for (int currentIndex = 0; currentIndex < [loginItems count]; currentIndex++)
    {
        LSSharedFileListItemRef currentItemRef = (LSSharedFileListItemRef)[loginItems objectAtIndex:currentIndex];
        if (LSSharedFileListItemResolve(currentItemRef, 0, (CFURLRef *) &itemUrl, NULL) == noErr) {
            if (itemUrl != nil && [[[itemUrl path] stringByStandardizingPath] isEqualToString:[[appUrl path] stringByStandardizingPath]]) {
                itemRef = currentItemRef;
            }
        }
    }
    
    if (itemRef != nil) CFRetain(itemRef);
    
    [loginItems release];
    CFRelease(loginItemsRef);
    
    return itemRef;
}

@end
