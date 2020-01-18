#import "Settings.h"

#define SAFARI_SWEEPER_USER_SETTINGS @"UserSettings"

@implementation Settings

@synthesize CleanSecureActive  = _CleanSecureActive;
@synthesize CleanActive        = _CleanActive;
@synthesize CleanCookies       = _CleanCookies;
@synthesize CleanZombieCookies = _CleanZombieCookies;
@synthesize CleanCache         = _CleanCache;
@synthesize CleanDownloads     = _CleanDownloads;
@synthesize CleanForms         = _CleanForms;
@synthesize CleanHistory       = _CleanHistory;
@synthesize CleanLocation      = _CleanLocation;
@synthesize CleanPreview       = _CleanPreview;
@synthesize CleanTopSites      = _CleanTopSites;
@synthesize CleanWebPageIcons  = _CleanWebPageIcons;

@synthesize CleanReadingList         = _CleanReadingList;
@synthesize CleanRemoteNotifications = _CleanRemoteNotifications;
@synthesize CleanOfflineData         = _CleanOfflineData;
@synthesize CleanMailDownloads = _CleanMailDownloads;


+ (id)settingsFromDefaults
{
    Settings *settings = nil;
    NSData   *data     = [[NSUserDefaults standardUserDefaults] objectForKey:SAFARI_SWEEPER_USER_SETTINGS];
    
    if ( data != nil ) {
        settings = (Settings *)[NSKeyedUnarchiver unarchiveObjectWithData:data];
    }
    
    if ( settings == nil )
    {
        settings = [[[Settings alloc] init] autorelease];

        settings.CleanActive        = NO;
        settings.CleanSecureActive  = NO;
        
        settings.CleanCache         = YES;
        settings.CleanCookies       = YES;
        settings.CleanZombieCookies = YES;
        settings.CleanDownloads     = YES;
        settings.CleanForms         = YES;
        settings.CleanHistory       = YES;
        settings.CleanLocation      = YES;
        settings.CleanPreview       = YES;
        settings.CleanTopSites      = YES;
        settings.CleanWebPageIcons  = YES;

        // Currently unused !!!
        //
//        settings.CleanReadingList         = NO;
//        settings.CleanRemoteNotifications = NO;
//        settings.CleanOfflineData         = NO;
//
//        settings.CleanMailDownloads = NO;
    }

    return settings;
}


/**
 save the settings in the user defaults
 */
- (void)saveSettings
{
    NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
    [prefs setObject:[NSKeyedArchiver archivedDataWithRootObject:self] forKey:SAFARI_SWEEPER_USER_SETTINGS];
    [prefs synchronize];
}


/**
 serialize object
 @param encoder systems encoder object
 */
- (void)encodeWithCoder:(NSCoder *)encoder
{
    [encoder encodeBool:self.CleanSecureActive forKey:@"cleanSecureActive"];
    [encoder encodeBool:self.CleanActive forKey:@"cleanActive"];
    
    [encoder encodeBool:self.CleanCookies forKey:@"cleanCookies"];
    [encoder encodeBool:self.CleanZombieCookies forKey:@"cleanZombieCookies"];
    [encoder encodeBool:self.CleanCache forKey:@"cleanCache"];
    [encoder encodeBool:self.CleanDownloads forKey:@"cleanDownloads"];
    [encoder encodeBool:self.CleanForms forKey:@"cleanForms"];
    [encoder encodeBool:self.CleanHistory forKey:@"cleanHistory"];
    [encoder encodeBool:self.CleanLocation forKey:@"cleanLocation"];
    [encoder encodeBool:self.CleanPreview forKey:@"cleanPreview"];
    [encoder encodeBool:self.CleanTopSites forKey:@"cleanTopSites"];
    [encoder encodeBool:self.CleanWebPageIcons forKey:@"cleanWebPageIcons"];

//    [encoder encodeBool:self.CleanReadingList forKey:@"cleanReadingList"];
//    [encoder encodeBool:self.CleanRemoteNotifications forKey:@"cleanRemoteNotifications"];
//    [encoder encodeBool:self.CleanOfflineData forKey:@"cleanOfflineData"];
//    [encoder encodeBool:self.CleanMailDownloads forKey:@"cleanMailDownloads"];
}


/**
 deserialize object
 @param encoder systems decoder object
 */
- (id)initWithCoder:(NSCoder *)decoder
{
    if ( (self = [super init]) ) 
    {
        self.CleanSecureActive  = [decoder decodeBoolForKey:@"cleanSecureActive"];
        self.CleanActive        = [decoder decodeBoolForKey:@"cleanActive"];
        
        self.CleanCookies       = [decoder decodeBoolForKey:@"cleanCookies"];
        self.CleanZombieCookies = [decoder decodeBoolForKey:@"cleanZombieCookies"];
        self.CleanCache         = [decoder decodeBoolForKey:@"cleanCache"];
        self.CleanDownloads     = [decoder decodeBoolForKey:@"cleanDownloads"];
        self.CleanForms         = [decoder decodeBoolForKey:@"cleanForms"];
        self.CleanHistory       = [decoder decodeBoolForKey:@"cleanHistory"];
        self.CleanLocation      = [decoder decodeBoolForKey:@"cleanLocation"];
        self.CleanPreview       = [decoder decodeBoolForKey:@"cleanPreview"];
        self.CleanTopSites      = [decoder decodeBoolForKey:@"cleanTopSites"];
        self.CleanWebPageIcons  = [decoder decodeBoolForKey:@"cleanWebPageIcons"];

//        self.CleanReadingList         = [decoder decodeBoolForKey:@"cleanReadingList"];
//        self.CleanRemoteNotifications = [decoder decodeBoolForKey:@"cleanRemoteNotifications"];
//        self.CleanOfflineData         = [decoder decodeBoolForKey:@"cleanOfflineData"];
//
//        self.CleanMailDownloads = [decoder decodeBoolForKey:@"cleanMailDownloads"];
    }

    return self;
}

@end
