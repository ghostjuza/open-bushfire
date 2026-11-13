#import <Sparkle/Sparkle.h>

#import "PanelController.h"
#import <QuartzCore/QuartzCore.h>
#import "BackgroundView.h"
#import "StatusItemView.h"
#import "MenubarController.h"
#import "Settings.h"
#import "LoginItemManager.h"
#import "AboutWindowController.h"
#import "SettingCheckboxCell.h"
#import "SweeperManager.h"
#import "Helper.h"
#import "Panel.h"
#import "LineView.h"
#import "DarkLineView.h"
#import "NSButton+TextColor.h"

#include <syslog.h>

#define OPEN_DURATION 0  //.15
#define CLOSE_DURATION 0.3 //.1
#define POPUP_HEIGHT 78
#define POPUP_HEIGHT_SMALL 226
#define POPUP_HEIGHT_CLOSED 76
#define PANEL_WIDTH 325
#define ROW_HEIGHT 32
#define DESIGN_HEIGHT 546  // Hoehe des Fensters in Panel.xib
#define DATACOUNT_Y -3     // feste y-Position des Textfelds "75 / 77 Objekte"

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


// Container mit Ursprung oben links: alle Positionen im Panel sind "Abstand von oben"
// Checkbox in Bushfire-Orange (unabhaengig von der Akzentfarbe des Systems)
@interface BFCheckboxCell : NSButtonCell
@end

@implementation BFCheckboxCell

- (void)drawWithFrame:(NSRect)cellFrame inView:(NSView *)controlView
{
    const CGFloat size = 16.0;
    const CGFloat k = size / 14.0;
    BOOL flipped = [controlView isFlipped];
    NSRect box = NSMakeRect(NSMinX(cellFrame) + 1.0, floor(NSMidY(cellFrame) - size / 2.0), size, size);
    BOOL on = ([self state] != NSControlStateValueOff);
    CGFloat alpha = ([self isEnabled] ? 1.0 : 0.4);
    
    NSBezierPath *path = [NSBezierPath bezierPathWithRoundedRect:NSInsetRect(box, 0.5, 0.5) xRadius:3.5 yRadius:3.5];
    
    if (on) {
        // Verlauf wie die Flamme: oben helles Orange, unten tiefes Rot-Orange
        NSColor *flameTop    = [NSColor colorWithCalibratedRed:0.96 green:0.52 blue:0.12 alpha:alpha];
        NSColor *flameBottom = [NSColor colorWithCalibratedRed:0.78 green:0.17 blue:0.07 alpha:alpha];
        NSGradient *gradient = [[[NSGradient alloc] initWithStartingColor:flameBottom endingColor:flameTop] autorelease];
        [gradient drawInBezierPath:path angle:(flipped ? -90.0 : 90.0)];
        [[NSColor colorWithCalibratedRed:0.55 green:0.10 blue:0.03 alpha:0.7 * alpha] setStroke];
        [path setLineWidth:0.8];
        [path stroke];
        
        NSBezierPath *check = [NSBezierPath bezierPath];
        CGFloat (^yy)(CGFloat) = ^CGFloat(CGFloat dy) { return (flipped ? NSMinY(box) + dy : NSMaxY(box) - dy); };
        [check moveToPoint:NSMakePoint(NSMinX(box) + 3.2 * k, yy(7.4 * k))];
        [check lineToPoint:NSMakePoint(NSMinX(box) + 5.9 * k, yy(10.2 * k))];
        [check lineToPoint:NSMakePoint(NSMinX(box) + 10.8 * k, yy(4.0 * k))];
        [check setLineWidth:2.0];
        [check setLineCapStyle:NSLineCapStyleRound];
        [check setLineJoinStyle:NSLineJoinStyleRound];
        [[NSColor colorWithCalibratedWhite:1.0 alpha:alpha] setStroke];
        [check stroke];
    }
    else {
        [[NSColor colorWithCalibratedWhite:1.0 alpha:0.10 * alpha] setFill];
        [path fill];
        [[NSColor colorWithCalibratedWhite:1.0 alpha:0.45 * alpha] setStroke];
        [path setLineWidth:1.0];
        [path stroke];
    }
    
    NSRect titleRect = cellFrame;
    titleRect.origin.x   += size + 6.0;
    titleRect.size.width -= size + 6.0;
    NSAttributedString *title = [self attributedTitle];
    NSSize textSize = [title size];
    titleRect.origin.y    = floor(NSMidY(cellFrame) - textSize.height / 2.0);
    titleRect.size.height = ceil(textSize.height);
    [title drawInRect:titleRect];
}

@end


// Badge hinter jeder Kategorie: "Objekte / Groesse". Grau bei 0, orange sonst.
// Faengt keine Klicks ab, die Checkbox darunter bleibt bedienbar.
@interface BFBadgeView : NSView
@property (nonatomic, copy) NSString *text;
@property (nonatomic, assign) BOOL empty;    // 0 / 0 B -> grau
@property (nonatomic, assign) BOOL dimmed;   // Kategorie ausgeschaltet
@property (nonatomic, assign) CGFloat rightEdge;
- (void)setText:(NSString *)text empty:(BOOL)empty dimmed:(BOOL)dimmed;
- (void)setText:(NSString *)text empty:(BOOL)empty dimmed:(BOOL)dimmed animated:(BOOL)animated;
@end

@implementation BFBadgeView
{
    NSTimer *_growTimer;
    NSDate  *_growStart;
    CGFloat  _growFromWidth;
    CGFloat  _growToWidth;
    CGFloat  _growFade;    // 0..1 Deckkraft waehrend des Aufziehens
}
@synthesize text = _text, empty = _empty, dimmed = _dimmed, rightEdge = _rightEdge;

- (void)dealloc
{
    [_growTimer invalidate];
    [_growStart release];
    [_text release];
    [super dealloc];
}
- (NSView *)hitTest:(NSPoint)point { return nil; }

+ (NSDictionary *)textAttributes
{
    return [NSDictionary dictionaryWithObjectsAndKeys:
            [NSFont boldSystemFontOfSize:10], NSFontAttributeName,
            nil];
}

- (void)setText:(NSString *)text empty:(BOOL)empty dimmed:(BOOL)dimmed
{
    self.text = text;
    _empty    = empty;
    _dimmed   = dimmed;
    [_growTimer invalidate];
    _growTimer = nil;
    _growFade = 1.0;
    
    CGFloat width = ceil([text sizeWithAttributes:[BFBadgeView textAttributes]].width) + 12.0;
    NSRect frame  = [self frame];
    frame.size.width = width;
    frame.origin.x   = self.rightEdge - width;
    [self setFrame:frame];
    [self setNeedsDisplay:YES];
}

// Setzt den neuen Text und zieht die Pille dabei weich von der alten auf die neue Breite auf
// (rechte Kante bleibt fest, Deckkraft blendet mit ein).
- (void)setText:(NSString *)text empty:(BOOL)empty dimmed:(BOOL)dimmed animated:(BOOL)animated
{
    CGFloat oldWidth = NSWidth([self frame]);
    [self setText:text empty:empty dimmed:dimmed];
    CGFloat newWidth = NSWidth([self frame]);
    
    [_growTimer invalidate];
    _growTimer = nil;
    _growFade = 1.0;
    
    if (!animated || [text length] == 0 || [self window] == nil || ![[self window] isVisible]) return;
    
    _growFromWidth = (oldWidth < 6.0 ? 6.0 : oldWidth);
    _growToWidth   = newWidth;
    _growFade      = 0.0;
    [_growStart release];
    _growStart = [[NSDate date] retain];
    _growTimer = [NSTimer scheduledTimerWithTimeInterval:(1.0 / 60.0) target:self selector:@selector(growTick:) userInfo:nil repeats:YES];
    [[NSRunLoop currentRunLoop] addTimer:_growTimer forMode:NSRunLoopCommonModes];
    [self growTick:nil];
}

- (void)growTick:(NSTimer *)timer
{
    static const NSTimeInterval kDuration = 0.30;
    CGFloat u = (CGFloat)(-[_growStart timeIntervalSinceNow] / kDuration);
    if (u >= 1.0) u = 1.0;
    CGFloat e = 1.0 - (1.0 - u) * (1.0 - u) * (1.0 - u);   // ease-out
    
    CGFloat width = _growFromWidth + (_growToWidth - _growFromWidth) * e;
    NSRect frame = [self frame];
    frame.size.width = width;
    frame.origin.x   = self.rightEdge - width;
    [self setFrame:frame];
    _growFade = e;
    [self setNeedsDisplay:YES];
    
    if (u >= 1.0) {
        [_growTimer invalidate];
        _growTimer = nil;
        _growFade = 1.0;
    }
}

- (void)drawRect:(NSRect)dirtyRect
{
    if ([self.text length] == 0) return;
    
    CGFloat alpha = (self.dimmed ? 0.45 : 1.0) * _growFade;
    NSRect r = [self bounds];
    NSBezierPath *pill = [NSBezierPath bezierPathWithRoundedRect:r xRadius:NSHeight(r) / 2.0 yRadius:NSHeight(r) / 2.0];
    
    NSColor *fill, *fg;
    if (self.empty) {
        fill = [NSColor colorWithCalibratedWhite:0.33 alpha:alpha];
        fg   = [NSColor colorWithCalibratedWhite:0.68 alpha:alpha];
    }
    else {
        fill = [NSColor colorWithCalibratedRed:0.80 green:0.33 blue:0.10 alpha:alpha];
        fg   = [NSColor colorWithCalibratedWhite:1.0 alpha:alpha];
    }
    [NSGraphicsContext saveGraphicsState];
    [pill addClip];   // Text darf beim Aufziehen nie ueber die Pille hinausragen
    [fill setFill];
    [pill fill];
    
    NSMutableDictionary *attrs = [NSMutableDictionary dictionaryWithDictionary:[BFBadgeView textAttributes]];
    [attrs setObject:fg forKey:NSForegroundColorAttributeName];
    NSSize ts = [self.text sizeWithAttributes:attrs];
    // Rechtsbuendig (6 pt Rand): im Endzustand identisch zu mittig, beim Aufziehen wird der Text von rechts "enthuellt".
    [self.text drawAtPoint:NSMakePoint(floor(NSWidth(r) - 6.0 - ts.width), floor((NSHeight(r) - ts.height) / 2.0)) withAttributes:attrs];
    [NSGraphicsContext restoreGraphicsState];
}

@end


@interface BFFlippedView : NSView
@end

@implementation BFFlippedView
- (BOOL)isFlipped { return YES; }
@end


// ---------------------------------------------------------------------------
// Oeffnen mit "Pop": Feder-Animation (leichtes Ueberschwingen) ueber Layer-Transform.
// Es wird nur eine Animation hinzugefuegt, der Layer selbst bleibt unveraendert (Identitaet).
// Nach dem Ende ist also immer der normale Zustand sichtbar.
// ---------------------------------------------------------------------------

// Gedaempfte Schwingung, u: 0..1 -> 0..1 (mit Ueberschwingen)
static CGFloat bfSpringProgress(CGFloat u)
{
    if (u >= 1.0) {
        return 1.0;
    }
    return 1.0 - exp(-5.0 * u) * cos(2.0 * M_PI * 1.2 * u);
}

// Hilfsfenster fuer den Pop beim Oeffnen: zeigt nur ein Standbild (Snapshot) des fertigen Panels und
// skaliert es per Feder-Animation. Das echte Panel (mit allen Views) wird dabei nicht verformt,
// bleibt unsichtbar und wird erst am Ende der Animation eingeblendet.
static NSWindow *bfPopWindow = nil;

static void bfClosePopWindow(void)
{
    if (bfPopWindow != nil) {
        [bfPopWindow orderOut:nil];
        [bfPopWindow release];
        bfPopWindow = nil;
    }
}


@interface PanelController()

@property (nonatomic, assign) BackgroundView *a_backgroundView;
@property (nonatomic, retain) NSView   *a_settingsView;
@property (nonatomic, retain) NSButton *a_btnSettings;
@property (nonatomic, retain) NSButton *a_btnBurnNow;
@property (nonatomic, retain) NSButton *a_btnCleanActive;
@property (nonatomic, retain) NSButton *a_btnSettingsAbout;
@property (nonatomic, retain) NSButton *a_btnSettingsQuit;
@property (nonatomic, retain) NSButton *a_btnUpdateCheck;
@property (nonatomic, retain) NSButton *a_chkStartup;
@property (nonatomic, retain) NSButton *a_btnCleanSecureActive;
@property (nonatomic, retain) NSButton *a_btnLogEnabled;
@property (nonatomic, retain) NSButton *a_btnPanelAnimation;
@property (nonatomic, retain) NSTextField *TfDataCountSize;
@property (nonatomic, retain) NSMutableDictionary *a_badges;   // tag -> BFBadgeView

// 10.6 workaround 
@property (assign) NSView *a_containerView;

@property (nonatomic, retain) Settings *a_settings;
@property (nonatomic, retain) AboutWindowController *a_aboutWindowController;
@property (nonatomic, retain) NSMutableArray *a_tableRows;
@property (nonatomic, retain) NSView *a_overlay;

- (void)openPanel;
- (void)closePanel;
- (void)restorePanel:(float)alpha;
- (void)resizePanel:(CGSize)size alpha:(float)alpha; // duration:(float)duration

- (NSRect)statusRectForWindow:(NSWindow *)window;

- (IBAction)actionCleanActive:(id)sender;
- (void)animatePanelResizeForCleanActive;
- (BOOL)popOpenPanel:(NSWindow *)panel fadeId:(NSUInteger)fadeId;
- (IBAction)actionCleanSecureActive:(id)sender;
- (IBAction)actionSettingsQuit:(id)sender;
- (IBAction)actionSettingsAbout:(id)sender;
- (IBAction)actionToggleLoginItems:(id)sender;
- (IBAction)actionSettings:(id)sender;
- (IBAction)actionPanelAnimation:(id)sender;
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
@synthesize a_btnLogEnabled         = _a_btnLogEnabled;
@synthesize a_btnPanelAnimation     = _a_btnPanelAnimation;
@synthesize a_btnSettingsAbout      = _a_btnSettingsAbout;
@synthesize a_btnSettingsQuit       = _a_btnSettingsQuit;
@synthesize a_chkStartup            = _a_chkStartup;
@synthesize a_tableRows             = _a_tableRows;
@synthesize a_btnUpdateCheck        = _a_btnUpdateCheck;
@synthesize a_containerView         = _a_containerView;
@synthesize TfDataCountSize         = _TfDataCountSize;
@synthesize a_badges                = _a_badges;
@synthesize a_overlay               = _a_overlay;


// Animationen sind bewusst abgeschaltet: animator mit Dauer 0 laesst Alpha/Frame
// unter macOS 11 in Zwischenzustaenden haengen (Panel bleibt halb transparent).
static bool ANIMATE = false;

// Weiches Einblenden beim Oeffnen: nur Alpha (kein Frame), kurze Dauer, mit Absicherung.
// Der Zaehler verhindert, dass ein veralteter Einblend-Durchlauf einen neuen oder
// bereits geschlossenen Zustand ueberschreibt.
#define PANEL_FADE_IN_DURATION PANEL_FADE_DURATION
static NSUInteger bfPanelFadeId = 0;

// Zoom beim Oeffnen: das Panel waechst von 90 % auf 100 %, oben mittig (unter dem Menueleisten-Icon) verankert.
// Es wird nur eine Layer-Animation hinzugefuegt; der Layer selbst bleibt unveraendert (Identitaet),
// dadurch kann nach dem Ende nichts verkleinert haengen bleiben.
#define PANEL_POP_START_SCALE   0.55
#define PANEL_POP_DURATION      0.35
#define PANEL_FADE_DURATION     0.15

// Weiches Ein-/Ausklappen der Liste beim Klick auf die Checkbox "Safari": die Fensterhoehe wird per Timer
// in kleinen Schritten geaendert (oben fest). Am Ende setzt restorePanel: immer den exakten Endzustand.
// Der Zaehler macht veraltete Durchlaeufe (schnelle Klicks, Schliessen) wirkungslos.
#define PANEL_RESIZE_DURATION   0.22
static NSUInteger bfPanelResizeId = 0;


#pragma mark -

- (id)initWithDelegate:(id<PanelControllerDelegate>)delegate
{
    if ((self = [super initWithWindow:[PanelController createPanelWindow]])) {
        [[self window] setDelegate:self];
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
        [self buildInterface];
    }
    
    return self;
}


- (void)dealloc
{
    [_a_tableRows release];
    [_a_overlay release];
    [_a_aboutWindowController release];
    [_a_settingsView release];
    [_a_btnSettings release];
    [_a_btnBurnNow release];
    [_a_btnCleanActive release];
    [_a_btnCleanSecureActive release];
    [_a_btnLogEnabled release];
    [_a_btnPanelAnimation release];
    [_a_btnSettingsAbout release];
    [_a_btnSettingsQuit release];
    [_a_chkStartup release];
    [_TfDataCountSize release];
    [_a_badges release];
    
    [super dealloc];
}


#pragma mark - Datenmenge (Footer + Badges)

/**
 Mapping Zeile -> Scan-Kategorien (Helper). Einige Zeilen buendeln mehrere Kategorien.
 */
- (NSArray *)categoryNamesForRow:(NSInteger)row
{
    switch (row) {
        case SettingsModeCookies:     return @[@"CleanCookies", @"CleanFlashCookies"];
        case SettingsModeCache:       return @[@"CleanCache"];
        case SettingsModePreview:     return @[@"CleanPreview"];
        case SettingsModeHistory:     return @[@"CleanHistory"];
        case SettingsModeTopSites:    return @[@"CleanTopSites"];
        case SettingsModeForms:       return @[@"CleanForms"];
        case SettingsModeDownloads:   return @[@"CleanDownloads"];
        case SettingsModeLocation:    return @[@"CleanLocation"];
        case SettingsModeWebPageIcons:return @[@"CleanWebPageIcons"];
        case SettingsModeOfflineData: return @[@"CleanOfflineData", @"CleanLocalStorage"];
        default:                      return @[];   // z.B. Zombie-Cookies: wird nicht gezaehlt
    }
}

- (NSString *)badgeTextForCount:(NSUInteger)count size:(unsigned long long)size
{
    static NSNumberFormatter *intFmt = nil, *sizeFmt = nil;
    if (!intFmt) {
        intFmt = [[NSNumberFormatter alloc] init];
        [intFmt setNumberStyle:NSNumberFormatterDecimalStyle];
        sizeFmt = [[NSNumberFormatter alloc] init];
        [sizeFmt setNumberStyle:NSNumberFormatterDecimalStyle];
        [sizeFmt setMaximumFractionDigits:1];
    }
    
    NSString *unit = @"B";
    double value = (double) size;
    NSArray *units = @[@"KB", @"MB", @"GB", @"TB"];
    for (NSString *u in units) {
        if (value < 1024.0) break;
        value /= 1024.0;
        unit = u;
    }
    [sizeFmt setMaximumFractionDigits:(value >= 100.0 || [unit isEqualToString:@"B"] ? 0 : 1)];
    
    return [NSString stringWithFormat:@"%@ / %@ %@",
            [intFmt stringFromNumber:[NSNumber numberWithUnsignedInteger:count]],
            [sizeFmt stringFromNumber:[NSNumber numberWithDouble:value]], unit];
}

/**
 Aktualisiert Footer und Badges. Der Scan laeuft im Hintergrund (Helper).
 useCache:YES nach (De-)Aktivieren einer Zeile: die Daten auf der Platte haben sich nicht geaendert.
 */
- (void)refreshDataCountUseCache:(BOOL)useCache
{
    if (!useCache) {
        for (BFBadgeView *badge in [self.a_badges allValues]) {
            [badge setText:@"\u2026" empty:YES dimmed:NO];   // "..." waehrend der Zaehlung
        }
    }
    
    [Helper detectDataCountAndSizeForPanel:self.a_settings
        targetTextField:self.TfDataCountSize
        useCache:useCache
        perCategory:^(NSDictionary *byCategory)
    {
        for (NSNumber *tag in [self.a_badges allKeys]) {
            NSUInteger count = 0;
            unsigned long long size = 0;
            
            for (NSString *name in [self categoryNamesForRow:[tag integerValue]]) {
                NSDictionary *entry = [byCategory objectForKey:name];
                count += [[entry objectForKey:@"count"] unsignedIntegerValue];
                size  += [[entry objectForKey:@"size"] unsignedLongLongValue];
            }
            
            BFBadgeView *badge = [self.a_badges objectForKey:tag];
            [badge setText:[self badgeTextForCount:count size:size]
                     empty:(count == 0 && size == 0)
                    dimmed:![self isSettingActiveForRow:[tag integerValue]]
                  animated:(self.a_settings.PanelAnimationEnabled
                            && [badge.text isEqualToString:@"\u2026"]   // nur beim ersten Eintreffen der Werte, nicht beim (De-)Aktivieren
                            && ![[NSWorkspace sharedWorkspace] accessibilityDisplayShouldReduceMotion])];
        }
    }];
}


#pragma mark - UI aufbauen (ohne XIB)

+ (NSPanel *)createPanelWindow
{
    NSRect rect = NSMakeRect(0, 0, PANEL_WIDTH, POPUP_HEIGHT_CLOSED);
    Panel *panel = [[Panel alloc] initWithContentRect:rect
                                            styleMask:(NSWindowStyleMaskBorderless | NSWindowStyleMaskNonactivatingPanel)
                                              backing:NSBackingStoreBuffered
                                                defer:NO];
    [panel setReleasedWhenClosed:NO];
    [panel setAnimationBehavior:NSWindowAnimationBehaviorNone];
    [panel setCollectionBehavior:(NSWindowCollectionBehaviorCanJoinAllSpaces | NSWindowCollectionBehaviorIgnoresCycle)];
    [panel setAcceptsMouseMovedEvents:YES];
    [panel setFloatingPanel:NO];
    [panel setLevel:NSTornOffMenuWindowLevel];
    [panel setOpaque:NO];
    [panel setBackgroundColor:[NSColor clearColor]];
    [panel setHasShadow:YES];
    [panel setMovable:NO];
    // Dunkles Erscheinungsbild: Checkboxen und Text passen zum dunklen Hintergrund
    [panel setAppearance:[NSAppearance appearanceNamed:NSAppearanceNameDarkAqua]];
    
    BackgroundView *background = [[BackgroundView alloc] initWithFrame:rect];
    [background setAutoresizesSubviews:NO];
    [panel setContentView:background];
    [background release];
    
    return [panel autorelease];
}


- (NSAttributedString *)whiteTitle:(NSString *)title font:(NSFont *)font alignment:(NSTextAlignment)alignment
{
    NSMutableParagraphStyle *style = [[[NSMutableParagraphStyle alloc] init] autorelease];
    [style setAlignment:alignment];
    NSDictionary *attrs = [NSDictionary dictionaryWithObjectsAndKeys:
                           [NSColor whiteColor], NSForegroundColorAttributeName,
                           font, NSFontAttributeName,
                           style, NSParagraphStyleAttributeName,
                           nil];
    return [[[NSAttributedString alloc] initWithString:(title ? title : @"") attributes:attrs] autorelease];
}


- (NSButton *)checkboxWithFrame:(NSRect)frame title:(NSString *)title bold:(BOOL)bold action:(SEL)action
{
    NSButton *button = [[[NSButton alloc] initWithFrame:frame] autorelease];
    [button setCell:[[[BFCheckboxCell alloc] init] autorelease]];
    [button setButtonType:NSButtonTypeSwitch];
    NSFont *font = (bold ? [NSFont boldSystemFontOfSize:13] : [NSFont systemFontOfSize:13]);
    [button setAttributedTitle:[self whiteTitle:title font:font alignment:NSTextAlignmentLeft]];
    [button setTarget:self];
    [button setAction:action];
    return button;
}


- (NSButton *)iconButtonWithFrame:(NSRect)frame image:(NSString *)image pressed:(NSString *)pressed action:(SEL)action
{
    NSButton *button = [[[NSButton alloc] initWithFrame:frame] autorelease];
    [button setButtonType:NSButtonTypeMomentaryChange];
    [button setBordered:NO];
    [button setImagePosition:NSImageOnly];
    [button setImageScaling:NSImageScaleProportionallyDown];
    [button setImage:[NSImage imageNamed:image]];
    [button setAlternateImage:[NSImage imageNamed:pressed]];
    [button setTarget:self];
    [button setAction:action];
    return button;
}


- (NSButton *)pillButtonWithFrame:(NSRect)frame title:(NSString *)title action:(SEL)action
{
    NSButton *button = [[[NSButton alloc] initWithFrame:frame] autorelease];
    [button setButtonType:NSButtonTypeMomentaryChange];
    [button setBordered:NO];
    [button setImagePosition:NSImageOverlaps];
    [button setImageScaling:NSImageScaleAxesIndependently];
    [button setImage:[NSImage imageNamed:@"btn_ok_default"]];
    [button setAlternateImage:[NSImage imageNamed:@"btn_ok_default_pressed"]];
    [button setAttributedTitle:[self whiteTitle:title font:[NSFont systemFontOfSize:12] alignment:NSTextAlignmentCenter]];
    [button setTarget:self];
    [button setAction:action];
    return button;
}


- (void)buildInterface
{
    NSView *content = [[self window] contentView];
    self.a_backgroundView = (BackgroundView *)content;
    
    // Overlay mit Ursprung oben links
    BFFlippedView *overlay = [[[BFFlippedView alloc] initWithFrame:[content bounds]] autorelease];
    self.a_overlay = overlay;
    [content addSubview:overlay];
    
    // --- Kopfzeile ---
    self.a_btnCleanActive = [self checkboxWithFrame:NSMakeRect(12, 21, 215, 18) title:NSLocalizedString(@"clean_active", nil) bold:YES action:@selector(actionCleanActive:)];
    [self.a_btnCleanActive setState:self.a_settings.CleanActive];
    [overlay addSubview:self.a_btnCleanActive];
    
    self.a_chkStartup = [self checkboxWithFrame:NSMakeRect(12, 21, 250, 18) title:NSLocalizedString(@"start_logon", nil) bold:YES action:@selector(actionToggleLoginItems:)];
    [self.a_chkStartup setHidden:YES];
    [overlay addSubview:self.a_chkStartup];
    
    self.a_btnBurnNow = [self iconButtonWithFrame:NSMakeRect(PANEL_WIDTH - 74, 14, 32, 32) image:@"btn_burn_now" pressed:@"btn_burn_now_pressed" action:@selector(actionBurnNow:)];
    [overlay addSubview:self.a_btnBurnNow];
    
    self.a_btnSettings = [self iconButtonWithFrame:NSMakeRect(PANEL_WIDTH - 44, 14, 32, 32) image:@"btn_settings" pressed:@"btn_settings_pressed" action:@selector(actionSettings:)];
    [overlay addSubview:self.a_btnSettings];
    
    // --- Liste mit Einstellungen (Zeilen + Trennlinien) ---
    BFFlippedView *container = [[[BFFlippedView alloc] initWithFrame:NSMakeRect(0, 0, PANEL_WIDTH, POPUP_HEIGHT + ROW_HEIGHT * self.a_tableRows.count)] autorelease];
    self.a_containerView = container;
    [overlay addSubview:container];
    
    CGFloat listTop = 45.0;
    NSUInteger current = 0;
    
    for (NSDictionary *settingDict in self.a_tableRows)
    {
        CGFloat rowY = listTop + current * ROW_HEIGHT;
        NSInteger tag = [[settingDict objectForKey:@"tag"] integerValue];
        
        NSButton *settingButton = [self checkboxWithFrame:NSMakeRect(12, rowY + 7, PANEL_WIDTH - 24, 18)
                                                    title:[settingDict objectForKey:@"title"]
                                                     bold:NO
                                                   action:@selector(setSettingForRow:)];
        settingButton.tag = tag;
        [settingButton setState:[self isSettingActiveForRow:tag]];
        [container addSubview:settingButton];
        
        // Badge (rechtsbuendig, ueber der Checkbox, klickdurchlaessig).
        // Nicht fuer Zombie-Cookies: das ist ein Dienst, dort gibt es nichts zu zaehlen.
        if (!self.a_badges) self.a_badges = [NSMutableDictionary dictionary];
        if (tag != SettingsModeZombieCookies) {
            BFBadgeView *badge = [[[BFBadgeView alloc] initWithFrame:NSMakeRect(PANEL_WIDTH - 12, rowY + 7.5, 0, 17)] autorelease];
            badge.rightEdge = PANEL_WIDTH - 12;
            [container addSubview:badge];
            [self.a_badges setObject:badge forKey:[NSNumber numberWithInteger:tag]];
        }
        
        // Trennlinie unter der Zeile (dunkel + hell), nicht nach der letzten Zeile
        if (current + 1 < [self.a_tableRows count]) {
            DarkLineView *dark = [[[DarkLineView alloc] initWithFrame:NSMakeRect(1, rowY + ROW_HEIGHT - 1, PANEL_WIDTH - 2, 1)] autorelease];
            LineView *light    = [[[LineView alloc] initWithFrame:NSMakeRect(1, rowY + ROW_HEIGHT, PANEL_WIDTH - 2, 1)] autorelease];
            [container addSubview:dark];
            [container addSubview:light];
        }
        current++;
    }
    
    // --- Einstellungsseite (Zahnrad) ---
    BFFlippedView *settingsView = [[[BFFlippedView alloc] initWithFrame:NSMakeRect(0, 0, PANEL_WIDTH, POPUP_HEIGHT_SMALL)] autorelease];
    self.a_settingsView = settingsView;
    [settingsView setHidden:YES];
    [overlay addSubview:settingsView];
    
    self.a_btnCleanSecureActive = [self checkboxWithFrame:NSMakeRect(12, 53, 200, 18) title:NSLocalizedString(@"clean_secure_active", nil) bold:NO action:@selector(actionCleanSecureActive:)];
    [self.a_btnCleanSecureActive setState:self.a_settings.CleanSecureActive];
    [self.a_btnCleanSecureActive setFrameSize:NSMakeSize(PANEL_WIDTH - 80, 18)];   // Platz fuer den laengeren Titel, endet vor "Log"
    [self.a_btnCleanSecureActive setToolTip:NSLocalizedString(@"clean_secure_tooltip", nil)];
    [settingsView addSubview:self.a_btnCleanSecureActive];
    
    // Hinweis unter der Checkbox (sichtbar, kein Tooltip noetig)
    NSTextField *secureHint = [[[NSTextField alloc] initWithFrame:NSMakeRect(12 + 22, 72, PANEL_WIDTH - 24 - 22, 14)] autorelease];
    [secureHint setBezeled:NO];
    [secureHint setBordered:NO];
    [secureHint setDrawsBackground:NO];
    [secureHint setEditable:NO];
    [secureHint setSelectable:NO];
    [secureHint setAlignment:NSTextAlignmentLeft];
    [secureHint setFont:[NSFont systemFontOfSize:10]];
    [secureHint setTextColor:[NSColor colorWithCalibratedWhite:1.0 alpha:0.55]];
    [secureHint setStringValue:NSLocalizedString(@"clean_secure_hint", nil)];
    [settingsView addSubview:secureHint];
    
    self.a_btnLogEnabled = [self checkboxWithFrame:NSMakeRect(PANEL_WIDTH - 62, 53, 50, 18) title:NSLocalizedString(@"log_enabled", nil) bold:NO action:@selector(actionLogEnable:)];
    [self.a_btnLogEnabled setState:self.a_settings.LogEnabled];
    [settingsView addSubview:self.a_btnLogEnabled];
    
    self.a_btnPanelAnimation = [self checkboxWithFrame:NSMakeRect(12, 95, PANEL_WIDTH - 24, 18) title:NSLocalizedString(@"panel_animation", nil) bold:NO action:@selector(actionPanelAnimation:)];
    [self.a_btnPanelAnimation setState:self.a_settings.PanelAnimationEnabled];
    [settingsView addSubview:self.a_btnPanelAnimation];
    
    self.a_btnUpdateCheck = [self pillButtonWithFrame:NSMakeRect(round((PANEL_WIDTH - 175) / 2.0), 129, 175, 20) title:NSLocalizedString(@"update", nil) action:@selector(actionUpdateCheck:)];
    [settingsView addSubview:self.a_btnUpdateCheck];
    
    self.a_btnSettingsQuit = [self pillButtonWithFrame:NSMakeRect(round((PANEL_WIDTH - 175) / 2.0), 157, 175, 20) title:NSLocalizedString(@"quit", nil) action:@selector(actionSettingsQuit:)];
    [settingsView addSubview:self.a_btnSettingsQuit];
    
    self.a_btnSettingsAbout = [self pillButtonWithFrame:NSMakeRect(round((PANEL_WIDTH - 175) / 2.0), POPUP_HEIGHT_SMALL - 26, 175, 20) title:NSLocalizedString(@"about", nil) action:@selector(actionSettingsAbout:)];
    [settingsView addSubview:self.a_btnSettingsAbout];
    
    // --- Fußzeile: Anzahl / Größe ---
    NSTextField *label = [[[NSTextField alloc] initWithFrame:NSMakeRect(3, 0, PANEL_WIDTH - 6, 14)] autorelease];
    [label setBezeled:NO];
    [label setBordered:NO];
    [label setDrawsBackground:NO];
    [label setEditable:NO];
    [label setSelectable:NO];
    [label setAlignment:NSTextAlignmentCenter];
    [label setFont:[NSFont systemFontOfSize:11]];
    [label setTextColor:[NSColor whiteColor]];
    [label setStringValue:@""];
    self.TfDataCountSize = label;
    [overlay addSubview:label];
    
    // Startzustand
    [self.a_btnBurnNow setHidden:!self.a_settings.CleanActive];
    [self.a_containerView setHidden:!self.a_settings.CleanActive];
    
    [self.a_chkStartup setState:([LoginItemManager isLaunchAtStartup] ? NSControlStateValueOn : NSControlStateValueOff)];
    
    NSRect panelRect = [[self window] frame];
    panelRect.size.height = (self.a_settings.CleanActive ? POPUP_HEIGHT + (ROW_HEIGHT * self.a_tableRows.count) : POPUP_HEIGHT_CLOSED);
    [[self window] setFrame:panelRect display:NO];
    [self layoutPanelForHeight:panelRect.size.height];
}


- (void)loadWindow
{
    // Fenster wurde bereits im Initializer erzeugt (kein Nib)
}


- (void)windowDidLoad
{
    [super windowDidLoad];
}


/**
 Positioniert Overlay und Fußzeile fuer die aktuelle Fensterhoehe.
 Alle anderen Elemente haben feste Abstaende von oben (Overlay ist "flipped").
 */
- (void)layoutPanelForHeight:(CGFloat)height
{
    if (self.a_overlay == nil) {
        return;
    }
    [self.a_overlay setFrame:NSMakeRect(0, 0, PANEL_WIDTH, height)];
    [self.TfDataCountSize setFrame:NSMakeRect(3, height - 23, PANEL_WIDTH - 6, 14)];
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
    if (_hasActivePanel != flag) {
        _hasActivePanel = flag;
        if (_hasActivePanel) {
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
    if ([[self window] isVisible]) {
        self.hasActivePanel = NO;
    }
}


- (void)windowDidResize:(NSNotification *)notification
{
    [self layoutPanelForHeight:NSHeight([[[self window] contentView] frame])];
}


/**
 setzt die Panel-Spitze mittig unter das Statusleisten-Icon.
 Muss bei jedem Positionieren aufgerufen werden: windowDidResize feuert nicht, wenn sich nur die Position aendert.
 */
- (void)updateArrowForPanelRect:(NSRect)panelRect statusRect:(NSRect)statusRect
{
    CGFloat statusX = roundf(NSMidX(statusRect));
    self.a_backgroundView.arrowX = (NSInteger) (statusX - NSMinX(panelRect));
}


/**
 Bildschirm, auf dem das Panel erscheint (Fenster-Screen kann vor dem ersten Anzeigen nil sein)
 */
- (NSScreen *)screenForPanel:(NSWindow *)panel statusRect:(NSRect)statusRect
{
    NSScreen *screen = [panel screen];
    if (screen == nil) {
        NSPoint p = NSMakePoint(NSMidX(statusRect), NSMaxY(statusRect));
        for (NSScreen *candidate in [NSScreen screens]) {
            if (NSPointInRect(p, NSInsetRect([candidate frame], -1, -1))) {
                screen = candidate;
                break;
            }
        }
    }
    return (screen != nil ? screen : [NSScreen mainScreen]);
}


-(void)locateFrameDataCountSize:(CGSize)size
{
    [self layoutPanelForHeight:size.height];
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
    
    if ([self.Delegate respondsToSelector:@selector(statusItemViewForPanelController:)]) {
        statusItemView = [self.Delegate statusItemViewForPanelController:self];
    }
    
    if (statusItemView) {
        statusRect          = statusItemView.globalRect;
        statusRect.origin.y = NSMinY(statusRect) - NSHeight(statusRect);
    }
    else {
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
    
    NSRect statusRect = [self statusRectForWindow:panel];
    NSRect screenRect = [[self screenForPanel:panel statusRect:statusRect] frame];
    
    NSRect panelRect     = [panel frame];
    panelRect.size.width = PANEL_WIDTH;
    panelRect.origin.x   = roundf(NSMidX(statusRect) - NSWidth(panelRect) / 2);
    panelRect.origin.y   = NSMaxY(statusRect) - NSHeight(panelRect);
    
    if (NSMaxX(panelRect) > (NSMaxX(screenRect) - ARROW_HEIGHT)) {
        panelRect.origin.x -= NSMaxX(panelRect) - (NSMaxX(screenRect) - ARROW_HEIGHT);
    }
    
    [NSApp activateIgnoringOtherApps:NO];
    [panel setAlphaValue:0];
    [self updateArrowForPanelRect:panelRect statusRect:statusRect];
    [panel setFrame:panelRect display:YES];
    [panel makeKeyAndOrderFront:nil];
    
    BOOL animateOpen = (self.a_settings.PanelAnimationEnabled
                        && ![[NSWorkspace sharedWorkspace] accessibilityDisplayShouldReduceMotion]);
    
    // No animation
    if (!ANIMATE) {
        [self locateFrameDataCountSize:panelRect.size];
        [panel setFrame:panelRect display:YES];
        
        NSUInteger fadeId = ++bfPanelFadeId;
        bfClosePopWindow();   // Rest eines vorherigen Pops entfernen
        
        BOOL popped = NO;
        if (animateOpen) {
            // Badges zeigen "...", bis die Zaehlung fertig ist (Standbild enthaelt diesen Zustand)
            for (BFBadgeView *badge in [self.a_badges allValues]) {
                [badge setText:@"\u2026" empty:YES dimmed:NO];
            }
            popped = [self popOpenPanel:panel fadeId:fadeId];
        }
        
        if (!popped) {
            [panel setAlphaValue:1];
            [self refreshDataCountUseCache:NO];
        }
    }
    else {
        [self refreshDataCountUseCache:NO];
        NSTimeInterval openDuration = OPEN_DURATION;
        
        if ([[NSApp currentEvent] type] == NSEventTypeLeftMouseDown) {
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
 Pop beim Oeffnen: ein Standbild des fertigen Panels waechst in einem Hilfsfenster mit leichtem
 Ueberschwingen aus der Pfeilspitze. Am Ende wird das echte Panel eingeblendet und die Zaehlung gestartet.
 @returns NO, wenn kein Standbild erzeugt werden konnte (dann oeffnet das Panel ohne Animation)
 */
- (BOOL)popOpenPanel:(NSWindow *)panel fadeId:(NSUInteger)fadeId
{
    NSView *content = [panel contentView];
    NSRect bounds   = [content bounds];
    if (content == nil || NSIsEmptyRect(bounds)) {
        return NO;
    }
    
    NSBitmapImageRep *rep = [content bitmapImageRepForCachingDisplayInRect:bounds];
    if (rep == nil) {
        return NO;
    }
    [content cacheDisplayInRect:bounds toBitmapImageRep:rep];
    CGImageRef image = [rep CGImage];
    if (image == NULL) {
        return NO;
    }
    
    NSWindow *pop = [[NSWindow alloc] initWithContentRect:[panel frame]
                                                styleMask:NSWindowStyleMaskBorderless
                                                  backing:NSBackingStoreBuffered
                                                    defer:NO];
    [pop setReleasedWhenClosed:NO];
    [pop setAnimationBehavior:NSWindowAnimationBehaviorNone];
    [pop setOpaque:NO];
    [pop setBackgroundColor:[NSColor clearColor]];
    [pop setHasShadow:NO];
    [pop setIgnoresMouseEvents:YES];
    [pop setLevel:[panel level] + 1];
    [pop setCollectionBehavior:[panel collectionBehavior]];
    
    NSView *view = [[[NSView alloc] initWithFrame:bounds] autorelease];
    [view setWantsLayer:YES];
    [pop setContentView:view];
    
    CGFloat width  = NSWidth(bounds);
    CGFloat height = NSHeight(bounds);
    CGFloat tipX   = MAX(0.0, MIN(width, (CGFloat)self.a_backgroundView.arrowX));
    
    // Verankerung an der Pfeilspitze (oben, Hilfsfenster ist nicht gespiegelt: y = Hoehe ist oben)
    CALayer *layer     = [CALayer layer];
    layer.bounds       = CGRectMake(0, 0, width, height);
    layer.anchorPoint  = CGPointMake(tipX / width, 1.0);
    layer.position     = CGPointMake(tipX, height);
    layer.contents     = (id)image;
    layer.contentsScale = [panel backingScaleFactor];
    [[view layer] addSublayer:layer];
    
    NSMutableArray *values = [NSMutableArray array];
    const int steps = 40;
    for (int i = 0; i <= steps; i++) {
        CGFloat scale = PANEL_POP_START_SCALE + (1.0 - PANEL_POP_START_SCALE) * bfSpringProgress((CGFloat)i / (CGFloat)steps);
        [values addObject:[NSNumber numberWithDouble:scale]];
    }
    CAKeyframeAnimation *scaleAnim = [CAKeyframeAnimation animationWithKeyPath:@"transform.scale"];
    scaleAnim.values          = values;
    scaleAnim.duration        = PANEL_POP_DURATION;
    scaleAnim.calculationMode = kCAAnimationLinear;
    [layer addAnimation:scaleAnim forKey:@"bfPopScale"];
    
    CABasicAnimation *fadeAnim = [CABasicAnimation animationWithKeyPath:@"opacity"];
    fadeAnim.fromValue = [NSNumber numberWithFloat:0.0f];
    fadeAnim.toValue   = [NSNumber numberWithFloat:1.0f];
    fadeAnim.duration  = PANEL_FADE_DURATION;
    [layer addAnimation:fadeAnim forKey:@"bfPopFade"];
    
    bfPopWindow = pop;   // Besitz bleibt bei der statischen Variable
    [pop orderFront:nil];
    
    // Ende: echtes Panel einblenden (identisches Bild), Hilfsfenster danach entfernen, Zaehlung starten
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)((PANEL_POP_DURATION + 0.03) * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (fadeId != bfPanelFadeId) {
            return;   // inzwischen geschlossen oder neu geoeffnet
        }
        [panel setAlphaValue:1];
        [self refreshDataCountUseCache:NO];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (bfPopWindow == pop) {
                bfClosePopWindow();
            }
        });
    });
    
    return YES;
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
    
    NSRect statusRect = [self statusRectForWindow:panel];
    NSRect screenRect = [[self screenForPanel:panel statusRect:statusRect] frame];
    
    NSRect panelRect      = [panel frame];
    panelRect.size.height = size.height;
    panelRect.size.width  = size.width;
    panelRect.origin.x    = roundf(NSMidX(statusRect) - NSWidth(panelRect) / 2);
    panelRect.origin.y    = NSMaxY(statusRect) - NSHeight(panelRect);
    
    if (NSMaxX(panelRect) > (NSMaxX(screenRect) - ARROW_HEIGHT)) {
        panelRect.origin.x -= NSMaxX(panelRect) - (NSMaxX(screenRect) - ARROW_HEIGHT);
    }
    
    [NSApp activateIgnoringOtherApps:NO];
    
    //if ((@available(macOS 10.7, *)) && !(@available(macOS 10.10, *))) {
    //if (!@available(macOS 10.10, *)) {
    if ([Helper getOSVersion] < 101000) {
        [panel setAlphaValue:0];
    }
    
    [self updateArrowForPanelRect:panelRect statusRect:statusRect];
    [panel setFrame:panelRect display:YES];
    [self locateFrameDataCountSize:panelRect.size];
    [panel makeKeyAndOrderFront:nil];
    [panel setAlphaValue:alpha];
}


/**
 closes the overlay panel
 */
- (void)closePanel
{
    // No animation
    if (!ANIMATE) {
        bfPanelFadeId++;   // laufendes Einblenden ungueltig machen
        bfPanelResizeId++; // laufendes Ein-/Ausklappen ungueltig machen
        bfClosePopWindow();
        [[self window] setAlphaValue:0.0];
        [self restorePanel:0.0];
        [self close];
    }
    else {
        [NSAnimationContext beginGrouping];

        [[NSAnimationContext currentContext] setDuration:CLOSE_DURATION];
        [[[self window] animator] setAlphaValue:0.1];

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
    
    // Only the "active" selection changed, not the data on disk -> answer from scan cache
    //
    [self refreshDataCountUseCache:YES];
}


#pragma mark -
#pragma mark Actions


/**
 open settings dialog
 @param sender of nsbutton
 */
- (IBAction)actionSettings:(id)sender
{
    if (![self.a_btnCleanActive isHidden]) {
        [self resizePanel:CGSizeMake(PANEL_WIDTH, POPUP_HEIGHT_SMALL) alpha:1.0];
        
        [self.a_btnBurnNow setHidden:YES];
        [self.TfDataCountSize setHidden:YES];
        [self.a_btnCleanActive setHidden:YES];
        [self.a_containerView setHidden:YES];
        
        [self.a_chkStartup setState:([LoginItemManager isLaunchAtStartup] ? NSControlStateValueOn : NSControlStateValueOff)];
        [self.a_chkStartup setHidden:NO];
        [self.a_settingsView setHidden:NO];
        
        [self.a_btnSettings setImage:[NSImage imageNamed:@"btn_settings_pressed.png"]];
    } 
    else {
        //if (!isMyQueue()) {
        //    self.myQueue = dispatch_queue_create("QueDataCountAndSize", DISPATCH_QUEUE_SERIAL);
        //}
        //dispatch_queue_set_specific(self.myQueue, @selector(myQueue), @selector(myQueue), NULL);
        
        // dispatch_get_current_queue | dispatch_get_main_queue
        //dispatch_async(self.myQueue, ^ {
        [self refreshDataCountUseCache:YES];
        [self restorePanel:1.0];
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
    [alert setAlertStyle:NSAlertStyleWarning];
    
    [alert addButtonWithTitle:NSLocalizedString(@"ok", nil)];
    [alert addButtonWithTitle:NSLocalizedString(@"cancel", nil)];
    
    [alert setMessageText:NSLocalizedString(@"action_burn_now", nil)];
    [alert setInformativeText:NSLocalizedString(@"action_burn_now_long", nil)];
    
    [[NSApplication sharedApplication] activateIgnoringOtherApps:YES];
    
    if ([alert runModal] == NSAlertFirstButtonReturn) {
        [Helper log:LOG_NOTICE withMessage:@"User click: Burn Now"];
        SweeperManager *sweeperManager = [[SweeperManager alloc] init];
        [sweeperManager cleanupWithCompletion:nil];
        [sweeperManager release];
    }
}


-(NSTimeInterval)_getOpenDuaration
{
    NSTimeInterval openDuration = OPEN_DURATION;
    
    NSEvent *currentEvent = [NSApp currentEvent];
    NSUInteger clearFlags = ([currentEvent modifierFlags] & NSEventModifierFlagDeviceIndependentFlagsMask);
    
    BOOL shiftPressed = (clearFlags == NSEventModifierFlagShift);
    BOOL shiftOptionPressed = (clearFlags == (NSEventModifierFlagShift | NSEventModifierFlagOption));

    if (shiftPressed || shiftOptionPressed) {
        openDuration *= 10;
        if (shiftOptionPressed) {
            NSWindow *panel = [self window];
            
            NSRect screenRect = [[panel screen] frame];
            NSRect statusRect = [self statusRectForWindow:panel];
            NSRect panelRect  = [panel frame];
            
            [Helper log:LOG_NOTICE withMessage:[NSString stringWithFormat:@"Icon is at %@\n\tMenu is on screen %@\n\tWill be animated to %@", NSStringFromRect(statusRect), NSStringFromRect(screenRect), NSStringFromRect(panelRect)]];
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
    
    [self refreshDataCountUseCache:YES];
    [self animatePanelResizeForCleanActive];
}


/**
 klappt die Liste weich ein oder aus (Fensterhoehe animiert, Oberkante bleibt stehen)
 */
- (void)animatePanelResizeForCleanActive
{
    NSWindow *panel   = [self window];
    BOOL active       = self.a_settings.CleanActive;
    CGFloat targetH   = (active ? POPUP_HEIGHT + (ROW_HEIGHT * self.a_tableRows.count) : POPUP_HEIGHT_CLOSED);
    NSRect startFrame = [panel frame];
    CGFloat startH    = NSHeight(startFrame);
    
    if (!self.a_settings.PanelAnimationEnabled || ![panel isVisible] || fabs(targetH - startH) < 1.0 || [[NSWorkspace sharedWorkspace] accessibilityDisplayShouldReduceMotion]) {
        bfPanelResizeId++;
        [self restorePanel:1.0];
        return;
    }
    
    // Beim Aufklappen sofort sichtbar machen, beim Zuklappen erst am Ende verstecken (macht restorePanel:)
    [self.a_btnBurnNow setHidden:!active];
    if (active) {
        [self.a_containerView setHidden:NO];
    }
    
    NSUInteger animId     = ++bfPanelResizeId;
    CFTimeInterval begin  = CACurrentMediaTime();
    
    NSTimer *timer = [NSTimer timerWithTimeInterval:(1.0 / 60.0) repeats:YES block:^(NSTimer *t) {
        if (animId != bfPanelResizeId) {
            [t invalidate];
            return;
        }
        
        CGFloat progress = (CGFloat)((CACurrentMediaTime() - begin) / PANEL_RESIZE_DURATION);
        if (progress >= 1.0) {
            [t invalidate];
            [self restorePanel:1.0];   // exakter Endzustand
            return;
        }
        
        CGFloat eased = 1.0 - pow(1.0 - progress, 3.0);   // Ease-Out
        NSRect frame  = startFrame;
        frame.size.height = startH + (targetH - startH) * eased;
        frame.origin.y    = NSMaxY(startFrame) - NSHeight(frame);
        [panel setFrame:frame display:YES];
    }];
    [[NSRunLoop mainRunLoop] addTimer:timer forMode:NSRunLoopCommonModes];
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
 toggle global settings sweep
 @param sender of nsbutton
 */
- (IBAction)actionPanelAnimation:(id)sender
{
    self.a_settings.PanelAnimationEnabled = !self.a_settings.PanelAnimationEnabled;
    [self.a_settings saveSettings];
    [self.a_btnPanelAnimation setState:self.a_settings.PanelAnimationEnabled];
}


- (IBAction)actionLogEnable:(id)sender
{
    self.a_settings.LogEnabled = !self.a_settings.LogEnabled;
    [self.a_settings saveSettings];
    [self.a_btnLogEnabled setState:self.a_settings.LogEnabled];
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
    [self.a_chkStartup setState:([LoginItemManager isLaunchAtStartup] ? NSControlStateValueOn : NSControlStateValueOff)];
}


/**
 check for update.
 see: https://sparkle-project.org/documentation/
 see: https://christiantietze.de/posts/2019/06/sparkle-xpc-branch/
 
 @param sender of nsbutton
*/
- (IBAction)actionUpdateCheck:(id)sender
{
    [[[[SUUpdater alloc] init] autorelease] checkForUpdates:nil];
    //[[[SPUUpdater alloc] autorelease] checkForUpdates];
    //[[[SPUStandardUpdaterController alloc] autorelease] checkForUpdates:nil]; // SPUUpdater
}

@end
