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
	
    for ( id item in (NSArray *)loginItemsArray ) {		
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

+ (BOOL)isLaunchAtStartup
{
    LSSharedFileListItemRef itemRef = [self itemRefInLoginItems];
    BOOL isInList = itemRef != nil;
    if (itemRef != nil) CFRelease(itemRef);
    return isInList;
}

+ (void)toggleLaunchAtStartup
{
    BOOL shouldBeToggled = ![self isLaunchAtStartup];
    LSSharedFileListRef loginItemsRef = LSSharedFileListCreate(NULL, kLSSharedFileListSessionLoginItems, NULL);
    
    if (loginItemsRef == nil) return;
    
    if (shouldBeToggled) {
        CFURLRef appUrl = (CFURLRef)[NSURL fileURLWithPath:[[NSBundle mainBundle] bundlePath]];
        LSSharedFileListItemRef itemRef = LSSharedFileListInsertItemURL(loginItemsRef, kLSSharedFileListItemLast, NULL, NULL, appUrl, NULL, NULL);
        if (itemRef) CFRelease(itemRef);
    }
    else {
        LSSharedFileListItemRef itemRef = [self itemRefInLoginItems];
        LSSharedFileListItemRemove(loginItemsRef,itemRef);
        if (itemRef != nil) CFRelease(itemRef);
    }
    CFRelease(loginItemsRef);
}

+ (LSSharedFileListItemRef)itemRefInLoginItems
{
    LSSharedFileListItemRef itemRef = nil;
    NSURL *itemUrl = nil;
    NSURL *appUrl = [NSURL fileURLWithPath:[[NSBundle mainBundle] bundlePath]];
    LSSharedFileListRef loginItemsRef = LSSharedFileListCreate(NULL, kLSSharedFileListSessionLoginItems, NULL);
    
    if (loginItemsRef == nil) return nil;
    
    NSArray *loginItems = (NSArray *)LSSharedFileListCopySnapshot(loginItemsRef, nil);
    for (int currentIndex = 0; currentIndex < [loginItems count]; currentIndex++) {
        LSSharedFileListItemRef currentItemRef = (LSSharedFileListItemRef)[loginItems objectAtIndex:currentIndex];
        if (LSSharedFileListItemResolve(currentItemRef, 0, (CFURLRef *) &itemUrl, NULL) == noErr) {
            if ([itemUrl isEqual:appUrl]) {
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
