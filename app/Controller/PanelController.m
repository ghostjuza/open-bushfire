#import <Sparkle/Sparkle.h>

#import "PanelController.h"
#import "BackgroundView.h"
#import "StatusItemView.h"
#import "MenubarController.h"
#import "Settings.h"
#import "LoginItemManager.h"
#import "AboutWindowController.h"
#import "SettingCheckboxCell.h"
#import "SweeperManager.h"
#import "Helper.h"

#define OPEN_DURATION 0  //.15
#define CLOSE_DURATION 0 //.1
#define POPUP_HEIGHT 78
#define POPUP_HEIGHT_SMALL 200
#define POPUP_HEIGHT_CLOSED 76
#define PANEL_WIDTH 305
#define ROW_HEIGHT 32

enum {
    SettingsModeCache               = 0,
    SettingsModeCookies             = 1,
    SettingsModeZombieCookies       = 2,
    SettingsModePreview             = 3,
    SettingsModeHistory             = 4,
    SettingsModeTopSites            = 5,
    SettingsModeForms               = 6,
    SettingsModeDownloads           = 7,
    SettingsModeLocation            = 8,
    SettingsModeReadingList         = 9,
    SettingsModeRemoteNotifications = 10,
    SettingsModeMailDownloads       = 11,
    SettingsModeWebPageIcons        = 12,
    SettingsModeOfflineData         = 13
} SettingsMode;


@interface PanelController()

@property (nonatomic, assign) IBOutlet BackgroundView *a_backgroundView;
@property (nonatomic, retain) IBOutlet NSView   *a_settingsView;
@property (nonatomic, retain) IBOutlet NSButton *a_btnSettings;
@property (nonatomic, retain) IBOutlet NSButton *a_btnBurnNow;
@property (nonatomic, retain) IBOutlet NSButton *a_btnCleanActive;
@property (nonatomic, retain) IBOutlet NSButton *a_btnSettingsAbout;
@property (nonatomic, retain) IBOutlet NSButton *a_btnSettingsQuit;
@property (nonatomic, retain) IBOutlet NSButton *a_btnUpdateCheck;
@property (nonatomic, retain) IBOutlet NSButton *a_chkStartup;
@property (nonatomic, retain) IBOutlet NSButton *a_btnCleanSecureActive;
@property (nonatomic, retain) IBOutlet NSTextField *TfDataCountSize;

// 10.6 workaround 
@property (assign) IBOutlet NSView *a_containerView;

@property (nonatomic, retain) Settings *a_settings;
@property (nonatomic, retain) AboutWindowController *a_aboutWindowController;
@property (nonatomic, retain) NSMutableArray *a_tableRows;

- (void)openPanel;
- (void)closePanel;
- (void)restorePanel:(float)alpha;
- (void)resizePanel:(CGSize)size alpha:(float)alpha; // duration:(float)duration

- (NSRect)statusRectForWindow:(NSWindow *)window;

- (IBAction)actionCleanActive:(id)sender;
- (IBAction)actionCleanSecureActive:(id)sender;
- (IBAction)actionSettingsQuit:(id)sender;
- (IBAction)actionSettingsAbout:(id)sender;
- (IBAction)actionToggleLoginItems:(id)sender;
- (IBAction)actionSettings:(id)sender;
- (IBAction)actionBurnNow:(id)sender;

@end

@implementation PanelController

@synthesize Delegate                = _Delegate;
@synthesize hasActivePanel          = _hasActivePanel;
@synthesize a_settings              = _a_settings;
@synthesize a_backgroundView        = _a_backgroundView;
@synthesize a_aboutWindowController = _a_aboutWindowController;
@synthesize a_settingsView          = _a_settingsView;
@synthesize a_btnSettings           = _a_btnSettings;
@synthesize a_btnBurnNow            = _a_btnBurnNow;
@synthesize a_btnCleanActive        = _a_btnCleanActive;
@synthesize a_btnCleanSecureActive  = _a_btnCleanSecureActive;
@synthesize a_btnSettingsAbout      = _a_btnSettingsAbout;
@synthesize a_btnSettingsQuit       = _a_btnSettingsQuit;
@synthesize a_chkStartup            = _a_chkStartup;
@synthesize a_tableRows             = _a_tableRows;
@synthesize a_btnUpdateCheck        = _a_btnUpdateCheck;
@synthesize a_containerView         = _a_containerView;
@synthesize TfDataCountSize         = _TfDataCountSize;


static bool ANIMATE = false;


#pragma mark -

- (id)initWithDelegate:(id<PanelControllerDelegate>)delegate
{
    if ((self = [super initWithWindowNibName:@"Panel"]))
    {
        _Delegate    = delegate;
        _a_tableRows = [[NSMutableArray alloc] initWithObjects:
            [NSDictionary dictionaryWithObjectsAndKeys:NSLocalizedString(@"cookies",nil), @"title", [NSNumber numberWithInt:SettingsModeCookies], @"tag", nil],
            [NSDictionary dictionaryWithObjectsAndKeys:NSLocalizedString(@"zombie_cookies",nil), @"title", [NSNumber numberWithInt:SettingsModeZombieCookies], @"tag", nil],
            [NSDictionary dictionaryWithObjectsAndKeys:NSLocalizedString(@"cache",nil), @"title", [NSNumber numberWithInt:SettingsModeCache], @"tag", nil],
            [NSDictionary dictionaryWithObjectsAndKeys:NSLocalizedString(@"history",nil), @"title", [NSNumber numberWithInt:SettingsModeHistory], @"tag", nil],
            [NSDictionary dictionaryWithObjectsAndKeys:NSLocalizedString(@"downloads",nil), @"title", [NSNumber numberWithInt:SettingsModeDownloads], @"tag", nil],
            [NSDictionary dictionaryWithObjectsAndKeys:NSLocalizedString(@"top_sites",nil), @"title", [NSNumber numberWithInt:SettingsModeTopSites], @"tag", nil],
            [NSDictionary dictionaryWithObjectsAndKeys:NSLocalizedString(@"preview",nil), @"title", [NSNumber numberWithInt:SettingsModePreview], @"tag", nil],
            [NSDictionary dictionaryWithObjectsAndKeys:NSLocalizedString(@"forms",nil), @"title", [NSNumber numberWithInt:SettingsModeForms], @"tag", nil],
            [NSDictionary dictionaryWithObjectsAndKeys:NSLocalizedString(@"location",nil), @"title", [NSNumber numberWithInt:SettingsModeLocation], @"tag", nil],
            [NSDictionary dictionaryWithObjectsAndKeys:NSLocalizedString(@"web_page_icons",nil), @"title", [NSNumber numberWithInt:SettingsModeWebPageIcons], @"tag", nil],
            [NSDictionary dictionaryWithObjectsAndKeys:NSLocalizedString(@"offline_data",nil), @"title", [NSNumber numberWithInt:SettingsModeOfflineData], @"tag", nil],

            //[NSDictionary dictionaryWithObjectsAndKeys:NSLocalizedString(@"downloads_mail",nil), @"title", [NSNumber numberWithInt:SettingsModeMailDownloads], @"tag", nil],
            //[NSDictionary dictionaryWithObjectsAndKeys:NSLocalizedString(@"reading_list",nil), @"title", [NSNumber numberWithInt:SettingsModeReadingList], @"tag", nil],
            //[NSDictionary dictionaryWithObjectsAndKeys:NSLocalizedString(@"remote_notifications",nil), @"title", [NSNumber numberWithInt:SettingsModeRemoteNotifications], @"tag", nil],

            nil
        ];
        self.a_settings = [Settings settingsFromDefaults];
    }
    
    return self;
}


- (void)dealloc
{
    [_a_tableRows release];
    [_a_aboutWindowController release];
    [_a_settingsView release];
    [_a_btnSettings release];
    [_a_btnBurnNow release];
    [_a_btnCleanActive release];
    [_a_btnCleanSecureActive release];
    [_a_btnSettingsAbout release];
    [_a_btnSettingsQuit release];
    [_a_chkStartup release];
    [_a_containerView release];
    [_TfDataCountSize release];
    
    [super dealloc];
}


- (void)awakeFromNib
{
    [super awakeFromNib];
    
//    ANIMATE = ([Helper getOSVersion] >= 1010 ? NO : YES);
    
    // Make a fully skinned panel
    NSPanel *panel = (id)[self window];
    [panel setAcceptsMouseMovedEvents:YES];
    [panel setFloatingPanel:NO];
    [panel setLevel:NSTornOffMenuWindowLevel];
    [panel setOpaque:NO];
    [panel setBackgroundColor:[NSColor clearColor]];
    
    // Resize panel
    NSRect panelRect = [[self window] frame];
    panelRect.size.height = ( self.a_settings.CleanActive ? POPUP_HEIGHT + (ROW_HEIGHT * self.a_tableRows.count) : POPUP_HEIGHT_CLOSED );
    [[self window] setFrame:panelRect display:NO];
    
    // set translations
    [self.a_btnSettingsQuit setTitle:NSLocalizedString(@"quit", nil)];
    [self.a_btnSettingsAbout setTitle:NSLocalizedString(@"about", nil)];
    [self.a_btnUpdateCheck setTitle:NSLocalizedString(@"update", nil)];
    [self.a_chkStartup setTitle:NSLocalizedString(@"start_logon", nil)];
    
    // Set text colors
    [self.a_btnUpdateCheck setTextColor:[NSColor whiteColor]];
    [self.a_btnSettingsAbout setTextColor:[NSColor whiteColor]];
    [self.a_btnSettingsQuit setTextColor:[NSColor whiteColor]];
    [self.a_chkStartup setTextColor:[NSColor whiteColor]];
    
    [self.a_btnSettings.cell setShowsStateBy:NSPushInCellMask]; 
    [self.a_btnSettings.cell setHighlightsBy:NSContentsCellMask];
    
    [self.a_btnSettingsAbout.cell setShowsStateBy:NSPushInCellMask];
    [self.a_btnSettingsAbout.cell setHighlightsBy:NSContentsCellMask];
    
    [self.a_btnSettingsQuit.cell setShowsStateBy:NSPushInCellMask]; 
    [self.a_btnSettingsQuit.cell setHighlightsBy:NSContentsCellMask];
    
    [self.a_btnUpdateCheck.cell setShowsStateBy:NSPushInCellMask];
    [self.a_btnUpdateCheck.cell setHighlightsBy:NSContentsCellMask];
    
    [self.a_btnCleanSecureActive setIntValue:self.a_settings.CleanSecureActive];
    [self.a_btnCleanSecureActive setTitle:NSLocalizedString(@"clean_secure_active", nil)];
    
    [self.a_btnCleanActive setIntValue:self.a_settings.CleanActive];
    [self.a_btnCleanActive setTitle:NSLocalizedString(@"clean_active", nil)];
    
    
    NSString * appPath = [[NSBundle mainBundle] bundlePath];
    LSSharedFileListRef loginItems = LSSharedFileListCreate(NULL, kLSSharedFileListSessionLoginItems, NULL);
    
    if (loginItems)
    {
        [self.a_chkStartup setState:[LoginItemManager loginItemExistsWithLoginItemReference:loginItems ForPath:appPath]];
        CFRelease(loginItems);
    }
    
    [self.a_containerView setHidden:!self.a_settings.CleanActive];
    
    int current = 0;
    
    for (NSDictionary *settingDict in self.a_tableRows)
    {
        int settingBtnOriginY   = (int) (-16 + [self.a_tableRows count] * ROW_HEIGHT - current * ROW_HEIGHT);
        NSButton *settingButton = [[NSButton alloc] initWithFrame:NSMakeRect(12, settingBtnOriginY, PANEL_WIDTH - 20, ROW_HEIGHT)];
        settingButton.tag       = [[settingDict objectForKey:@"tag"] integerValue];

        [settingButton setCell:[[SettingCheckboxCell alloc] init]];
        [settingButton setAction:@selector(setSettingForRow:)];
        [settingButton setButtonType:NSSwitchButton];
        [settingButton setBezelStyle:0];
        [settingButton setState:[self isSettingActiveForRow:[[settingDict objectForKey:@"tag"] integerValue]]];

        [settingButton.cell setTitle:[settingDict objectForKey:@"title"]];
        [settingButton.cell setShowsStateBy:NSContentsCellMask];
        [settingButton.cell setHighlightsBy:NSContentsCellMask];
        [settingButton.cell setButtonType:NSMomentaryPushInButton];
        [settingButton.cell setBackgroundColor:[NSColor clearColor]];

        [self.a_containerView addSubview:settingButton];
        
        current++;
    }
}


#pragma mark - Public accessors

/**
 bool about if the panel is active
 @returns bool if the panel is active
 */
- (BOOL)hasActivePanel
{
    return _hasActivePanel;
}


/**
 set the panel active/inactive
 @param flag active/inactive flag
 */
- (void)setHasActivePanel:(BOOL)flag
{
    if ( _hasActivePanel != flag )
    {
        _hasActivePanel = flag;
        
        if ( _hasActivePanel ) {
            [self openPanel];
        }
        else {
            [self closePanel];
        }
    }
}

#pragma mark - NSWindowDelegate

- (void)windowWillClose:(NSNotification *)notification
{
    self.hasActivePanel = NO;
}


- (void)windowDidResignKey:(NSNotification *)notification;
{
    if ( [[self window] isVisible] ) {
        self.hasActivePanel = NO;
    }
}


- (void)windowDidResize:(NSNotification *)notification
{
    NSWindow *panel   = [self window];
    NSRect statusRect = [self statusRectForWindow:panel];
    NSRect panelRect  = [panel frame];
    
    CGFloat statusX   = roundf(NSMidX(statusRect));
    CGFloat panelX    = statusX - NSMinX(panelRect);
        
    self.a_backgroundView.arrowX = panelX;
}


-(void)locateFrameDataCountSize:(CGSize)size
{
    NSRect textFieldFrame = [self.TfDataCountSize frame];
    int positionOffset = (int) -55;
    
//#if DEBUG == 1
//    
//    NSLog(@"CGSizeH [%d]", (int)size.height);
//    NSLog(@"TfDataCountSize isHidden [%@]", ([[self TfDataCountSize] isHidden] ? @"Yes" : @"No"));
//    NSLog(@"originTextRectY [%d] originTextRectH [%d]", (int)textFieldFrame.origin.y, (int)textFieldFrame.size.height);
//    
//#endif
    
    if (size.height == POPUP_HEIGHT_CLOSED) {
        textFieldFrame.origin.y = positionOffset;
    }
    else
    {
        int openPosition = (int) ((2 + ([self.a_tableRows count] * ROW_HEIGHT)) * (-1));
        textFieldFrame.origin.y = openPosition + positionOffset;
    }
//    
//#if DEBUG == 1
//    
//    NSLog(@"textRectY [%d] textRectX [%d]", (int)textFieldFrame.origin.y, (int)textFieldFrame.origin.x);
//    
//#endif
    
    [self.TfDataCountSize setFrame:textFieldFrame];
}


#pragma mark - Keyboard

- (void)cancelOperation:(id)sender
{
    self.hasActivePanel = NO;
}


#pragma mark - Public methods

/**
 get the status rect for the current window
 @param window current window
 @returns rect for the status item view
 */
- (NSRect)statusRectForWindow:(NSWindow *)window
{
    NSRect screenRect = [[window screen] frame];
    NSRect statusRect = NSZeroRect;
    
    StatusItemView *statusItemView = nil;
    
    if ( [self.Delegate respondsToSelector:@selector(statusItemViewForPanelController:)] ) {
        statusItemView = [self.Delegate statusItemViewForPanelController:self];
    }
    
    if ( statusItemView )
    {
        statusRect          = statusItemView.globalRect;
        statusRect.origin.y = NSMinY(statusRect) - NSHeight(statusRect);
    }
    else
    {
        statusRect.size     = NSMakeSize(STATUS_ITEM_VIEW_WIDTH, [[NSStatusBar systemStatusBar] thickness]);
        statusRect.origin.x = roundf((NSWidth(screenRect) - NSWidth(statusRect)) / 2);
        statusRect.origin.y = NSHeight(screenRect) - NSHeight(statusRect) * 2;
    }

    return statusRect;
}


/**
 opens the overlay panel with animation
 */
- (void)openPanel
{
    NSWindow *panel = [self window];
    
    NSRect screenRect = [[panel screen] frame];
    NSRect statusRect = [self statusRectForWindow:panel];
    
    NSRect panelRect     = [panel frame];
    panelRect.size.width = PANEL_WIDTH;
    panelRect.origin.x   = roundf(NSMidX(statusRect) - NSWidth(panelRect) / 2);
    panelRect.origin.y   = NSMaxY(statusRect) - NSHeight(panelRect);
    
    if ( NSMaxX(panelRect) > (NSMaxX(screenRect) - ARROW_HEIGHT) ) {
        panelRect.origin.x -= NSMaxX(panelRect) - (NSMaxX(screenRect) - ARROW_HEIGHT);
    }
    
    [NSApp activateIgnoringOtherApps:NO];
    [panel setAlphaValue:0];
    [panel setFrame:statusRect display:YES];
    [panel makeKeyAndOrderFront:nil];
    
    [Helper detectDataCountAndSize:self.a_settings targetTextField:self.TfDataCountSize];
    
    if (!ANIMATE) // No animation
    {
        [self locateFrameDataCountSize:panelRect.size];
        
        [panel setFrame:panelRect display:YES];
        [panel setAlphaValue:1];
    }
    else
    {
        NSTimeInterval openDuration = OPEN_DURATION;
        
        if ([[NSApp currentEvent] type] == NSLeftMouseDown) {
            openDuration = [self _getOpenDuaration];
        }
        
        [NSAnimationContext beginGrouping];
        
        [self locateFrameDataCountSize:panelRect.size];
        
        [[NSAnimationContext currentContext] setDuration:openDuration];
        [[panel animator] setFrame:panelRect display:YES];
        [[panel animator] setAlphaValue:1];
        
        [NSAnimationContext endGrouping];
    }
}


/**
 restore default panel
 */
- (void)restorePanel:(float)alpha
{
    [self resizePanel:CGSizeMake(PANEL_WIDTH, (self.a_settings.CleanActive ? POPUP_HEIGHT + (ROW_HEIGHT * self.a_tableRows.count) : POPUP_HEIGHT_CLOSED)) alpha:alpha];
    
    [self.TfDataCountSize setHidden:NO];
    [self.a_btnCleanActive setHidden:NO];
    [self.a_btnBurnNow setHidden:!self.a_settings.CleanActive];
    
    [self.a_chkStartup setHidden:YES];
    [self.a_settingsView setHidden:YES];
    
    [self.a_containerView setHidden:!self.a_settings.CleanActive];
    [self.a_btnSettings setImage:[NSImage imageNamed:@"btn_settings.png"]];
}


/**
 resize the panel animated
 @param size new size of panel
 @param duration of panel resize animation
 */
- (void)resizePanel:(CGSize)size alpha:(float)alpha
{
    NSWindow *panel   = [self window];
    
    NSRect screenRect = [[panel screen] frame];
    NSRect statusRect = [self statusRectForWindow:panel];
    
    NSRect panelRect      = [panel frame];
    panelRect.size.height = size.height;
    panelRect.size.width  = size.width;
    panelRect.origin.x    = roundf(NSMidX(statusRect) - NSWidth(panelRect) / 2);
    panelRect.origin.y    = NSMaxY(statusRect) - NSHeight(panelRect);
    
    if ( NSMaxX(panelRect) > (NSMaxX(screenRect) - ARROW_HEIGHT) ) {
        panelRect.origin.x -= NSMaxX(panelRect) - (NSMaxX(screenRect) - ARROW_HEIGHT);
    }
    
    [NSApp activateIgnoringOtherApps:NO];
    
    //if ((@available(macOS 10.7, *)) && !(@available(macOS 10.10, *))) {
    //if (!@available(macOS 10.10, *)) {
    if ([Helper getOSVersion] < 101000) {
        [panel setAlphaValue:0];
    }
    
    [panel setFrame:statusRect display:YES];
    [panel makeKeyAndOrderFront:nil];
    
    if (!ANIMATE) // No animation
    {
        //[panel setFrame:statusRect display:NO];
        
        [self locateFrameDataCountSize:panelRect.size];
        
        [panel setFrame:panelRect display:YES];
        [panel setAlphaValue:alpha];
    }
    else
    {
        //@TODO: This line of code is a workaround for locateFrameDataCountSize !!!
        [panel setFrame:statusRect display:NO];
        [self locateFrameDataCountSize:panelRect.size];
        
        [NSAnimationContext beginGrouping];
        
        [[NSAnimationContext currentContext] setDuration:OPEN_DURATION];
        [[panel animator] setFrame:panelRect display:YES];
        [[panel animator] setAlphaValue:alpha];
        
        [NSAnimationContext endGrouping];
    }
}


/**
 closes the overlay panel
 */
- (void)closePanel
{
    if (!ANIMATE) // No animation
    {
        [[self window] setAlphaValue:0.0];
        [self restorePanel:0.0];
        [self close];
    }
    else
    {
        [NSAnimationContext beginGrouping];

        [[NSAnimationContext currentContext] setDuration:CLOSE_DURATION];
        [[[self window] animator] setAlphaValue:0];

        [NSAnimationContext endGrouping];
        
        //@TODO: ?!
        [self performSelector:@selector(restorePanel:) withObject:[NSNumber numberWithFloat:0.0] afterDelay:CLOSE_DURATION];
        //[self close];
        
        dispatch_after(dispatch_walltime(NULL, NSEC_PER_SEC * CLOSE_DURATION * 2), dispatch_get_main_queue(), ^{
            [self close];
        });
    }
}


/**
 check whether setting is active or not
 @param row current table row
 @returns setting active/inactive
 */
- (BOOL)isSettingActiveForRow:(NSInteger)row 
{
    switch (row) 
    {
        case SettingsModeCache:
            return self.a_settings.CleanCache;
            break;

        case SettingsModeCookies:
            return self.a_settings.CleanCookies;
            break;
            
        case SettingsModeZombieCookies:
            return self.a_settings.CleanZombieCookies;
            break;

        case SettingsModePreview:
            return self.a_settings.CleanPreview;
            break;

        case SettingsModeHistory:
            return self.a_settings.CleanHistory;
            break;

        case SettingsModeTopSites:
            return self.a_settings.CleanTopSites;
            break;

        case SettingsModeForms:
            return self.a_settings.CleanForms;
            break;

        case SettingsModeDownloads:
            return self.a_settings.CleanDownloads;
            break;

        case SettingsModeMailDownloads:
            return self.a_settings.CleanMailDownloads;
            break;

        case SettingsModeLocation:
            return self.a_settings.CleanLocation;
            break;

        case SettingsModeReadingList:
            return self.a_settings.CleanReadingList;
            break;

        case SettingsModeRemoteNotifications:
            return self.a_settings.CleanRemoteNotifications;
            break;

        case SettingsModeWebPageIcons:
            return self.a_settings.CleanWebPageIcons;
            break;

        case SettingsModeOfflineData:
            return self.a_settings.CleanOfflineData;
            break;
    }

    return NO;
}


/**
 set setting to active/inactive
 @param row current table row
 */
- (IBAction)setSettingForRow:(NSButton *)button
{
    switch (button.tag)
    {
        case SettingsModeCache:
            self.a_settings.CleanCache = ![self isSettingActiveForRow:button.tag];
            break;

        case SettingsModeCookies:
            self.a_settings.CleanCookies = ![self isSettingActiveForRow:button.tag];
            break;
            
        case SettingsModeZombieCookies:
            self.a_settings.CleanZombieCookies = ![self isSettingActiveForRow:button.tag];
            break;

        case SettingsModePreview:
            self.a_settings.CleanPreview = ![self isSettingActiveForRow:button.tag];
            break;

        case SettingsModeHistory:
            self.a_settings.CleanHistory = ![self isSettingActiveForRow:button.tag];
            break;

        case SettingsModeTopSites:
            self.a_settings.CleanTopSites = ![self isSettingActiveForRow:button.tag];
            break;

        case SettingsModeForms:
            self.a_settings.CleanForms = ![self isSettingActiveForRow:button.tag];
            break;

        case SettingsModeDownloads:
            self.a_settings.CleanDownloads = ![self isSettingActiveForRow:button.tag];
            break;

        case SettingsModeMailDownloads:
            self.a_settings.CleanMailDownloads = ![self isSettingActiveForRow:button.tag];
            break;

        case SettingsModeLocation:
            self.a_settings.CleanLocation = ![self isSettingActiveForRow:button.tag];
            break;

        case SettingsModeReadingList:
            self.a_settings.CleanReadingList = ![self isSettingActiveForRow:button.tag];
            break;

        case SettingsModeRemoteNotifications:
            self.a_settings.CleanRemoteNotifications = ![self isSettingActiveForRow:button.tag];
            break;

        case SettingsModeWebPageIcons:
            self.a_settings.CleanWebPageIcons = ![self isSettingActiveForRow:button.tag];
            break;

        case SettingsModeOfflineData:
            self.a_settings.CleanOfflineData = ![self isSettingActiveForRow:button.tag];
            break;
    }

    [self.a_settings saveSettings];
    
    // Detect data counts and sizes
    //
    [Helper detectDataCountAndSize:self.a_settings targetTextField:self.TfDataCountSize];
}


#pragma mark -
#pragma mark Actions


/**
 open settings dialog
 @param sender of nsbutton
 */
- (IBAction)actionSettings:(id)sender
{
    if (![self.a_btnCleanActive isHidden])
    {
        [self resizePanel:CGSizeMake(PANEL_WIDTH, POPUP_HEIGHT_SMALL) alpha:1.0];
        
        [self.a_btnBurnNow setHidden:YES];
        [self.TfDataCountSize setHidden:YES];
        [self.a_btnCleanActive setHidden:YES];
        [self.a_containerView setHidden:YES];
        
        [self.a_chkStartup setHidden:NO];
        [self.a_settingsView setHidden:NO];
        
        [self.a_btnSettings setImage:[NSImage imageNamed:@"btn_settings_pressed.png"]];
    } 
    else
    {
        //if (!isMyQueue()) {
        //    self.myQueue = dispatch_queue_create("QueDataCountAndSize", DISPATCH_QUEUE_SERIAL);
        //}
        //dispatch_queue_set_specific(self.myQueue, @selector(myQueue), @selector(myQueue), NULL);
        
        // dispatch_get_current_queue | dispatch_get_main_queue
        //dispatch_async(self.myQueue, ^ {
        dispatch_async(dispatch_get_main_queue(), ^ {
            [Helper detectDataCountAndSize:self.a_settings targetTextField:self.TfDataCountSize];
            [self restorePanel:1.0];
        });
    }
}


/**
 open settings dialog
 @param sender of nsbutton
 */
- (IBAction)actionBurnNow:(id)sender
{
    [self alertActionBurnNow];
}

- (void) alertActionBurnNow
{
    NSAlert *alert = [[[NSAlert alloc] init] autorelease];
    [alert setAlertStyle:NSWarningAlertStyle];
    
    [alert addButtonWithTitle:NSLocalizedString(@"ok", nil)];
    [alert addButtonWithTitle:NSLocalizedString(@"cancel", nil)];
    
    [alert setMessageText:NSLocalizedString(@"action_burn_now", nil)];
    [alert setInformativeText:NSLocalizedString(@"action_burn_now_long", nil)];
    
    [[NSApplication sharedApplication] activateIgnoringOtherApps:YES];
    
    if ([alert runModal] == NSAlertFirstButtonReturn)
    {
        NSLog(@"%@", @"User click: Burn Now");
        
        SweeperManager *sweeperManager = [[SweeperManager alloc] init];
        [sweeperManager cleanupWithCompletion:nil];
        [sweeperManager release];
    }
}


-(NSTimeInterval)_getOpenDuaration
{
    NSTimeInterval openDuration = OPEN_DURATION;
    
    NSEvent *currentEvent = [NSApp currentEvent];
    NSUInteger clearFlags = ([currentEvent modifierFlags] & NSDeviceIndependentModifierFlagsMask);
    
    BOOL shiftPressed       = (clearFlags == NSShiftKeyMask);
    BOOL shiftOptionPressed = (clearFlags == (NSShiftKeyMask | NSAlternateKeyMask));

    if ( shiftPressed || shiftOptionPressed )
    {
        openDuration *= 10;
        
        if (shiftOptionPressed)
        {
            NSWindow *panel = [self window];
            
            NSRect screenRect = [[panel screen] frame];
            NSRect statusRect = [self statusRectForWindow:panel];
            NSRect panelRect  = [panel frame];
            
            NSLog(@"Icon is at %@\n\tMenu is on screen %@\n\tWill be animated to %@", NSStringFromRect(statusRect), NSStringFromRect(screenRect), NSStringFromRect(panelRect));
        }
    }
    
    return openDuration;
}


/**
 toggle global settings sweep
 @param sender of nsbutton
 */
- (IBAction)actionCleanActive:(id)sender
{
    self.a_settings.CleanActive = !self.a_settings.CleanActive;
    [self.a_settings saveSettings];
    
    [self.a_btnCleanActive setState:self.a_settings.CleanActive];
    [self.a_containerView setHidden:YES];
    
    //if (!isMyQueue()) {
    //    self.myQueue = dispatch_queue_create("QueDataCountAndSize", DISPATCH_QUEUE_SERIAL);
    //}
    //dispatch_queue_set_specific(self.myQueue, @selector(myQueue), @selector(myQueue), NULL);
    
    // dispatch_get_current_queue | dispatch_get_main_queue
    //dispatch_async(self.myQueue, ^{
    dispatch_async(dispatch_get_main_queue(), ^ {
        [Helper detectDataCountAndSize:self.a_settings targetTextField:self.TfDataCountSize];
        [self restorePanel:1.0];
    });
}


// https://github.com/inkling/Subliminal/issues/164
//BOOL isMyQueue(void)
//{
//    return dispatch_get_specific(@selector(myQueue)) != NULL;
//}


/**
 toggle global settings sweep
 @param sender of nsbutton
 */
- (IBAction)actionCleanSecureActive:(id)sender
{
    self.a_settings.CleanSecureActive = !self.a_settings.CleanSecureActive;
    [self.a_settings saveSettings];
    [self.a_btnCleanSecureActive setState:self.a_settings.CleanSecureActive];
}


/**
 terminate app
 @param sender of nsbutton
 */
- (IBAction)actionSettingsQuit:(id)sender
{
    [NSApp terminate:self];
}


/**
 open about dialog
 @param sender of nsbutton
 */
- (IBAction)actionSettingsAbout:(id)sender
{
    if (self.a_aboutWindowController == nil) {
        _a_aboutWindowController = [[AboutWindowController alloc] initWithWindowNibName:@"AboutWindowController"];
    }
    [self.a_aboutWindowController showWindow:self];
    [self closePanel];
}


/**
 toggle that the app should start on login
 @param sender of nsbutton
 */
- (IBAction)actionToggleLoginItems:(id)sender 
{
    [LoginItemManager toggleLaunchAtStartup];
    [self.a_chkStartup setState:[LoginItemManager isLaunchAtStartup]];
}


/**
 update check
 @param sender of nsbutton
*/
- (IBAction)actionUpdateCheck:(id)sender
{
    [[[[SUUpdater alloc] init] autorelease] checkForUpdates:nil];
    //[[[SPUStandardUpdaterController alloc] autorelease] checkForUpdates:nil]; // SPUUpdater
}

@end
