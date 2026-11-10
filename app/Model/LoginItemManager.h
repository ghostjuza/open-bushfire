@interface LoginItemManager : NSObject

+ (BOOL)isLaunchAtStartup;
+ (NSString *)launchAgentPath;
+ (void)toggleLaunchAtStartup;

@end
