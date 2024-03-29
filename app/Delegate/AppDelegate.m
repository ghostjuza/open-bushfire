#import <Sparkle/Sparkle.h>
#import "AppDelegate.h"
#import "SweeperManager.h"
#import "Helper.h"
#import "Curl.h"

#include <syslog.h>

void *kContextActivePanel = &kContextActivePanel;

@interface AppDelegate()

@property (nonatomic, retain) SweeperManager *a_sweeperManager;
@property (nonatomic, retain) MenubarController *a_menubarController;
@property (nonatomic, retain, readonly) PanelController *a_panelController;
@property (nonatomic, retain) Settings *a_settings;

- (IBAction)togglePanel:(id)sender;
- (void)m_safariTerminated:(NSNotification *)note;

@end



@implementation AppDelegate

@synthesize a_sweeperManager = _a_sweeperManager;
@synthesize a_menubarController = _a_menubarController;
@synthesize a_panelController = _a_panelController;
@synthesize a_settings = _a_settings;

static MenubarController *m_staticMenubarController;


+ (MenubarController*) getMenubarController
{
    return m_staticMenubarController;
}



#pragma mark -

- (void)dealloc
{
    [_a_menubarController release];
    [_a_panelController removeObserver:self forKeyPath:@"hasActivePanel"];
    [_a_panelController release];
    [_a_settings release];
    [super dealloc];
}


#pragma mark -

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (context == kContextActivePanel) {
        self.a_menubarController.hasActiveIcon = self.panelController.hasActivePanel;
    }
    else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}


#pragma mark - NSApplicationDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)notification
{
    BOOL isConnectionAvailable = [Helper isConnected];
    
    // Remove quarantine flags from this App !!!
    //
#if RMQ == 1

    NSString *appPath = [[NSBundle mainBundle] bundlePath];
    NSString *command = [NSString stringWithFormat:@"xattr -dr com.apple.quarantine %@", appPath];
    
    int retVal = system([command cStringUsingEncoding:NSUTF8StringEncoding]);
    
    #if DEBUG == 1
        [Helper log:LOG_NOTICE logMessage:[NSString stringWithFormat:@"[DBG] Remove quarantine flags <%d>", retVal]];
    #endif
    
#endif
    
    if(isConnectionAvailable) {
        [[[SUUpdater alloc] init] checkForUpdatesInBackground];
    }
    
    self.a_settings = [Settings settingsFromDefaults];

    if ([self checkSystemIntegrityProtection]) {
        [self checkFullDiskAccess];
    }
//    else if ([self checkSIPforAppIdentifier:@"com.apple.Terminal"]) {
//        [self checkSystemIntegrityProtection];
//    }
    
    // Install icon into the menu bar
    [self.a_menubarController = [[MenubarController alloc] init] release];
    m_staticMenubarController = self.a_menubarController;
    
    self.panelController.hasActivePanel = NO;

    NSNotificationCenter *center = [[NSWorkspace sharedWorkspace] notificationCenter];
    [center addObserver:self selector:@selector(m_safariTerminated:) name:NSWorkspaceDidTerminateApplicationNotification object:nil];
}


// Prototype Code !!!!
//
// Apple hat das Sicherheitskonzept namens „System Integrity Protection“ (SIP) – auch „Rootless“ genannt – mit OS X 10.11 El Capitan eingeführt.
// SIP sorgt dafür, dass Programme und Anwender selbst mit Root-Rechten keine System-Ordner von macOS mehr verändern können.
// Zudem sind Zugriffe auf laufende Prozesse und somit auch Debugging-Funktionen eingeschränkt.
// Deshalb funktionieren einige Tools, die weit in das System eingreifen, nur ohne SIP-Schutz so wie gewünscht.
// Quelle: https://www.heise.de/ratgeber/System-Integrity-Protection-SIP-in-macOS-deaktivieren-3946690.html
//
// SIP deaktivieren: "csrutil disable"
//
- (BOOL) checkSystemIntegrityProtection
{
    if (@available(macOS 10.14, *))
    {
        NSString *sipStatus = [Helper runCommand:@"csrutil status"];
        [Helper log:LOG_NOTICE logMessage:[NSString stringWithFormat:@"Detect %@", sipStatus]];
        bool isProtected = true;
        bool isSipUnknown = [Helper inString:sipStatus needle:@"unknown ("];
        
        if (!isSipUnknown && [Helper inString:sipStatus needle:@"enabled"]) {
            [Helper log:LOG_NOTICE logMessage:@"In SIP status condition: enabled"];
            if (!self.a_settings.SipEnabledConfirmed) {
                [self alertSystemIntegrityProtection];
            }
        }
        else if (!isSipUnknown && [Helper inString:sipStatus needle:@"disabled"]) {
            [Helper log:LOG_NOTICE logMessage:@"In SIP status condition: disabled"];
            isProtected = false;
            self.a_settings.SipUnknownConfirmed = self.a_settings.SipEnabledConfirmed = NO;
            [self.a_settings saveSettings];
        }
        else { // unknown
            [Helper log:LOG_NOTICE logMessage:@"In SIP status condition: unknown"];
            if (!self.a_settings.SipUnknownConfirmed) {
                [self alertSystemIntegrityProtectionUnknown];
            }
        }
        
        [Helper log:LOG_NOTICE logMessage:[NSString stringWithFormat:@"Status System Integrity Protection 'enabled' is confirmed: %@", (self.a_settings.SipEnabledConfirmed ? @"YES" : @"NO")]];
        [Helper log:LOG_NOTICE logMessage:[NSString stringWithFormat:@"Status System Integrity Protection 'unknown (custom configuration)' is confirmed: %@", (self.a_settings.SipUnknownConfirmed ? @"YES" : @"NO")]];
        
        return isProtected;
    }
    
    [Helper log:LOG_NOTICE logMessage:[NSString stringWithFormat:@"Detect System Integrity Protection status: %@", @"not available for this OS"]];
    return false;
}


- (BOOL) checkFullDiskAccess
{
    NSString *logMsg = @"Full Disk Access status: %@";
    
    if (@available(macOS 10.14, *)) {
        NSString *cmd = [NSString stringWithFormat:@"sqlite3 /Library/Application\\ Support/com.apple.TCC/TCC.db 'select service, client, auth_value from access where auth_value = 2 and service = \"kTCCServiceSystemPolicyAllFiles\" and client = \"%@\"'", [[NSBundle mainBundle] bundleIdentifier]];
        NSString *cmdResult = [Helper runCommand:cmd];
        if ([cmdResult length] == 0) {
            [Helper log:LOG_NOTICE logMessage:[NSString stringWithFormat:logMsg, @"not found or disabled"]];
            [self alertDiskFullAccess];
            return false;
        }
        [Helper log:LOG_NOTICE logMessage:[NSString stringWithFormat:logMsg, @"existing and activated"]];
    }
    else {
        [Helper log:LOG_NOTICE logMessage:[NSString stringWithFormat:logMsg, @"not available for this OS"]];
    }
    
    return true;
}


//- (BOOL)checkSIPforAppIdentifier:(NSString*)identifier {
//
//    // First available from 10.14 Mojave
//    if (@available(macOS 10.14, *)) {
//
////        int c = open("/Library/Application Support/com.apple.TCC/TCC.db", O_RDONLY);
////        if (c == -1 && (errno == EPERM || errno == EACCES)) {
////            // no full disk access
////            return NO;
////        }
//
//        OSStatus status;
//        NSAppleEventDescriptor *targetAppEventDescriptor;
//
//        targetAppEventDescriptor = [NSAppleEventDescriptor descriptorWithBundleIdentifier:identifier];
//        status = AEDeterminePermissionToAutomateTarget(targetAppEventDescriptor.aeDesc, typeWildCard, typeWildCard, true);
//
//        switch (status) {
//            case -600: //procNotFound
//                NSLog(@"Not running app with id <%@>", identifier);
//                break;
//
//            case 0: // noErr
//                NSLog(@"SIP check successfull for app with id <%@>", identifier);
//                break;
//
//            case -1744: // errAEEventWouldRequireUserConsent
//                // This only appears if you send false for askUserIfNeeded
//                NSLog(@"User consent required for app with id <%@>", identifier);
//                break;
//
//            case -1743: //errAEEventNotPermitted
//                NSLog(@"User didn't allow usage for app with id <%@>", identifier);
//
//                // Here you should present a dialog with a tutorial on how to activate it manually
//                // This can be something like
//                // Go to system preferences > security > privacy
//                // Choose automation and active [APPNAME] for [APPNAME]
//
//                return NO;
//
//            default:
//                break;
//        }
//    }
//    return YES;
//}


- (void) alertSystemIntegrityProtection
{
    NSAlert *alert = [[[NSAlert alloc] init] autorelease];
    [alert setAlertStyle:NSWarningAlertStyle];
    
    [alert addButtonWithTitle:NSLocalizedString(@"roger_that", nil)];
    [alert addButtonWithTitle:NSLocalizedString(@"dont_show_again", nil)];
    
    [alert setMessageText:NSLocalizedString(@"alert_sip", nil)];
    [alert setInformativeText:NSLocalizedString(@"alert_sip_long", nil)];
    
    [[NSApplication sharedApplication] activateIgnoringOtherApps:YES];
    
    if ([alert runModal] == NSAlertSecondButtonReturn) {
        self.a_settings.SipEnabledConfirmed = YES;
        [self.a_settings saveSettings];
    }
}

- (void) alertSystemIntegrityProtectionUnknown
{
    NSAlert *alert = [[[NSAlert alloc] init] autorelease];
    [alert setAlertStyle:NSWarningAlertStyle];
    
    [alert addButtonWithTitle:NSLocalizedString(@"roger_that", nil)];
    [alert addButtonWithTitle:NSLocalizedString(@"dont_show_again", nil)];
    
    [alert setMessageText:NSLocalizedString(@"alert_sip_unknown", nil)];
    [alert setInformativeText:NSLocalizedString(@"alert_sip_unknown_long", nil)];
    
    [[NSApplication sharedApplication] activateIgnoringOtherApps:YES];
    
    if ([alert runModal] == NSAlertSecondButtonReturn) {
        self.a_settings.SipUnknownConfirmed = YES;
        [self.a_settings saveSettings];
    }
}


- (void) alertDiskFullAccess
{
    NSAlert *alert = [[[NSAlert alloc] init] autorelease];
    [alert setAlertStyle:NSWarningAlertStyle];
    
    [alert addButtonWithTitle:NSLocalizedString(@"ok", nil)];
    
    [alert setMessageText:NSLocalizedString(@"alert_fda", nil)];
    [alert setInformativeText:NSLocalizedString(@"alert_fda_long", nil)];
    
    [[NSApplication sharedApplication] activateIgnoringOtherApps:YES];
    [alert runModal];
}


- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)theApplication
{
    return NO;
}


- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender
{
    // Explicitly remove the icon from the menu bar
    self.a_menubarController = nil;
    
    NSNotificationCenter *center = [[NSWorkspace sharedWorkspace] notificationCenter];
    [center removeObserver:self];
    
    if (self.a_sweeperManager)  {
        [_a_sweeperManager release];
    }
    
    return NSTerminateNow;
}


#pragma mark - Actions

/**
 action for toggling the overlay panel
 @param sender in this case status item
 */
- (IBAction)togglePanel:(id)sender
{
    self.a_menubarController.hasActiveIcon = !self.a_menubarController.hasActiveIcon;
    self.a_panelController.hasActivePanel  = self.a_menubarController.hasActiveIcon;
}


#pragma mark - Public accessors

/**
 public accessor for the PanelController
 @returns current PanelController
 */
- (PanelController *)panelController
{
    if (!self.a_panelController)
    {
        _a_panelController = [[PanelController alloc] initWithDelegate:self];
        [self.a_panelController addObserver:self forKeyPath:@"hasActivePanel" options:NSKeyValueObservingOptionInitial context:kContextActivePanel];
    }
    
    return self.a_panelController;
}


#pragma mark - PanelControllerDelegate

/**
 current view for the status item in the tabbar
 @param controller instance of PanelController
 @returns current StatusItemView
 */
- (StatusItemView *)statusItemViewForPanelController:(PanelController *)controller
{
    return self.a_menubarController.StatusItemView;
}


#pragma mark - Safari terminated

/**
 heart of the app, notification callback when app closes
 @param note close notification
 */
- (void)m_safariTerminated:(NSNotification *)note
{
    if ([[[note userInfo] objectForKey:@"NSApplicationName"] isEqualToString:@"Safari"])
    {
        if (!self.a_sweeperManager) {
            _a_sweeperManager = [[SweeperManager alloc] init];
        }
        [self.a_sweeperManager cleanupWithCompletion:nil];
    }
}

@end
