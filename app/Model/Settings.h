@interface Settings : NSObject

@property BOOL CleanActive;
@property BOOL CleanSecureActive;
@property BOOL CleanCookies;
@property BOOL CleanZombieCookies;
@property BOOL CleanCache;
@property BOOL CleanPreview;
@property BOOL CleanHistory;
@property BOOL CleanTopSites;
@property BOOL CleanForms;
@property BOOL CleanDownloads;
@property BOOL CleanMailDownloads;
@property BOOL CleanLocation;
@property BOOL CleanOfflineData;
@property BOOL CleanReadingList;
@property BOOL CleanRemoteNotifications;
@property BOOL CleanWebPageIcons;
@property BOOL SipEnabledConfirmed;

+ (id)settingsFromDefaults;
- (void)saveSettings;

@end
