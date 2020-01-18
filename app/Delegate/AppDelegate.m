#import <Sparkle/Sparkle.h>
#import "AppDelegate.h"
#import "SweeperManager.h"
#import "Helper.h"

void *kContextActivePanel = &kContextActivePanel;

@interface AppDelegate()

@property (nonatomic, retain) SweeperManager *a_sweeperManager;
@property (nonatomic, retain) MenubarController *a_menubarController;
@property (nonatomic, retain, readonly) PanelController *a_panelController;

- (IBAction)togglePanel:(id)sender;
- (void)m_safariTerminated:(NSNotification *)note;

@end



@implementation AppDelegate

@synthesize a_sweeperManager = _a_sweeperManager;
@synthesize a_menubarController = _a_menubarController;
@synthesize a_panelController = _a_panelController;

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
        NSLog(@"[DBG] Remove quarantine flags [%d].", retVal);
    #endif
    
#endif
    
    if(isConnectionAvailable) {
        [[[SUUpdater alloc] init] checkForUpdatesInBackground];
    }
    
    // Install icon into the menu bar
    [self.a_menubarController = [[MenubarController alloc] init] release];
    m_staticMenubarController = self.a_menubarController;
    
    self.panelController.hasActivePanel = NO;

    NSNotificationCenter *center = [[NSWorkspace sharedWorkspace] notificationCenter];
    [center addObserver:self selector:@selector(m_safariTerminated:) name:NSWorkspaceDidTerminateApplicationNotification object:nil];
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
