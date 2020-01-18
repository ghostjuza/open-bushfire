@interface LoginItemManager : NSObject

+ (void)enableLoginItemWithLoginItemsReference:(LSSharedFileListRef )theLoginItemsRefs ForPath:(NSString *)appPath;
+ (void)disableLoginItemWithLoginItemsReference:(LSSharedFileListRef )theLoginItemsRefs ForPath:(NSString *)appPath;
+ (BOOL)loginItemExistsWithLoginItemReference:(LSSharedFileListRef)theLoginItemsRefs ForPath:(NSString *)appPath;
+ (BOOL)isLaunchAtStartup;
+ (void)toggleLaunchAtStartup;

@end
