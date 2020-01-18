#import "AboutWindowController.h"
#import "Helper.h"

@implementation AboutWindowController

@synthesize TfDonate = _TfDonate;
@synthesize TfTitle = _TfTitle;
@synthesize TfVersion = _TfVersion;
@synthesize TfCopyright = _TfCopyright;

@synthesize BtnDonate = _BtnDonate;
@synthesize BtnForkMe = _BtnForkMe;
@synthesize BtnSite = _BtnSite;
@synthesize BtnClose = _BtnClose;
@synthesize BtnLicense = _BtnLicense;

- (void)awakeFromNib 
{
    [super awakeFromNib];
    
    NSPanel *panel = (id)[self window];

    [panel setAcceptsMouseMovedEvents:YES];
    [panel setLevel:NSTornOffMenuWindowLevel];
    [panel setOpaque:NO];
    [panel setBackgroundColor:[NSColor clearColor]];
    [panel setMovableByWindowBackground:YES];
}

- (void)windowDidLoad
{
    [super windowDidLoad];
      
    //NSString *version    = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"];
    NSString *version    = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"];
    NSString *versionTag = @"\nGNU General Public License v3.0";
    
    #if DEBUG == 1
        versionTag = @"\nDEBUG";
    #endif
    
    #if SANDBOX == 1
        versionTag = [versionTag stringByAppendingString:@" [SANDBOX]"];
    #endif
    
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"yyyy"];
    
    [self.TfDonate setStringValue:NSLocalizedString(@"donate", nil)];
    [self.TfTitle setStringValue:NSLocalizedString(@"app_title", nil)];
    [self.TfVersion setStringValue:[NSString stringWithFormat:NSLocalizedString(@"version", nil), version, versionTag]];
    
    [self.TfCopyright setStringValue:[NSString stringWithFormat:NSLocalizedString(@"about_copyright", nil), [dateFormatter stringFromDate:[NSDate date]]]];
    
    [self.BtnClose.cell setShowsStateBy:NSPushInCellMask];
    [self.BtnClose.cell setHighlightsBy:NSContentsCellMask];
    
    
    //[self.BtnSite setTitle:NSLocalizedString(@"open_site", nil)];
    //[self.BtnSite setTextColor:[NSColor whiteColor]];
    [self.BtnSite.cell setShowsStateBy:NSPushInCellMask];
    [self.BtnSite.cell setHighlightsBy:NSContentsCellMask];
    [self.BtnSite setToolTip:NSLocalizedString(@"website_hint", nil)];
    
    [self.BtnDonate.cell setShowsStateBy:NSPushInCellMask];
    [self.BtnDonate.cell setHighlightsBy:NSContentsCellMask];
    [self.BtnDonate setToolTip:NSLocalizedString(@"donate_hint", nil)];
    
    [self.BtnForkMe.cell setShowsStateBy:NSPushInCellMask];
    [self.BtnForkMe.cell setHighlightsBy:NSContentsCellMask];
    [self.BtnForkMe setToolTip:NSLocalizedString(@"forkme_hint", nil)];
    
    [self.BtnLicense.cell setShowsStateBy:NSPushInCellMask];
    [self.BtnLicense.cell setHighlightsBy:NSContentsCellMask];
    [self.BtnLicense setToolTip:NSLocalizedString(@"license_hint", nil)];
}

- (void)dealloc
{
    [_TfTitle release];
    [_TfVersion release];
    [_TfCopyright release];
    
    [_BtnSite release];
    [_BtnClose release];
    [_BtnDonate release];
    [_BtnForkMe release];
    [_BtnLicense release];
    
    [super dealloc];
}

- (IBAction)actionOpenSite:(id)sender
{
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:NSLocalizedString(@"open_website", nil)]];
    [self close];
}

- (IBAction)actionOpenDonate:(id)sender
{
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:NSLocalizedString(@"open_donate", nil)]];
    [self close];
}

- (IBAction)actionOpenForkMe:(id)sender
{
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:NSLocalizedString(@"open_forkme", nil)]];
    [self close];
}

- (IBAction)actionOpenLicense:(id)sender
{
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:NSLocalizedString(@"open_license", nil)]];
    [self close];
}

- (IBAction)actionClose:(id)sender
{
    [self close];
}

- (void)keyDown:(NSEvent *)event {
    if ([event keyCode] == 53) {
        [self close];
    }
}

@end
