#import "StatusItemView.h"

@implementation StatusItemView

@synthesize statusItem = _statusItem;
@synthesize image = _image;
@synthesize alternateImage = _alternateImage;
@synthesize isHighlighted = _isHighlighted;
@synthesize action = _action;
@synthesize target = _target;

#pragma mark -

- (id)initWithStatusItem:(NSStatusItem *)statusItem
{
    if ( (self = [super init]) ) {
        _statusItem = [statusItem retain];
        
        NSStatusBarButton *button = _statusItem.button;
        [button setTarget:self];
        [button setAction:@selector(statusButtonClicked:)];
        [button sendActionOn:NSEventMaskLeftMouseDown];
        [button setImagePosition:NSImageOnly];
    }
    return self;
}

- (void)dealloc
{
    [_statusItem release];
    [_image release];
    [_alternateImage release];
    [super dealloc];
}

#pragma mark -
#pragma mark Click

- (void)statusButtonClicked:(id)sender
{
    // Klickposition merken: dient als Rueckfallebene, falls das Fenster des Buttons
    // (macOS 11) keine brauchbare Position liefert
    _lastClickLocation = [NSEvent mouseLocation];
    _lastClickTime     = [NSDate timeIntervalSinceReferenceDate];
    NSLog(@"Bushfire: Statusitem-Klick, Event-Typ %ld", (long)[[NSApp currentEvent] type]);
    
    [NSApp sendAction:self.action to:self.target from:self];
}

#pragma mark -
#pragma mark Accessors

- (void)updateButtonImage
{
    NSImage *icon = self.image;
    
    if (icon != nil) {
        // Schwarze Icons als Template: macOS faerbt sie je nach Menueleiste und Highlight.
        // Das rote "clean"-Icon bleibt farbig.
        BOOL isClean = [[icon name] isEqualToString:@"ico_menubar_clean"];
        [icon setTemplate:!isClean];
    }
    
    self.statusItem.button.image = icon;
}

- (void)setHighlighted:(BOOL)newFlag
{
    if (_isHighlighted == newFlag) {
        return;
    }
    _isHighlighted = newFlag;
    [self.statusItem.button highlight:newFlag];
}

#pragma mark -

- (void)setImage:(NSImage *)newImage
{
    [newImage retain];
    [_image release];
    _image = newImage;
    [self updateButtonImage];
}

- (void)setAlternateImage:(NSImage *)newImage
{
    [newImage retain];
    [_alternateImage release];
    _alternateImage = newImage;
}

#pragma mark -

- (NSRect)globalRect
{
    NSStatusBarButton *button = self.statusItem.button;
    NSWindow *window = button.window;
    CGFloat thickness = [[NSStatusBar systemStatusBar] thickness];
    
    NSRect rect = NSZeroRect;
    if (window != nil) {
        NSRect inWindow = [button convertRect:[button bounds] toView:nil];
        rect = [window convertRectToScreen:inWindow];
        NSRect windowFrame = [window frame];
        rect.origin.y    = NSMinY(windowFrame);
        rect.size.height = NSHeight(windowFrame);
    }
    
    // Klick vor weniger als einer Sekunde?
    BOOL recentClick = (([NSDate timeIntervalSinceReferenceDate] - _lastClickTime) < 1.0);
    
    // Rueckfall: Position aus dem Mausklick, wenn die Button-Position fehlt oder weit vom Klick entfernt ist
    if (recentClick && (window == nil || NSWidth(rect) < 1 || fabs(NSMidX(rect) - _lastClickLocation.x) > 40)) {
        NSScreen *screen = [NSScreen mainScreen];
        for (NSScreen *candidate in [NSScreen screens]) {
            if (NSPointInRect(_lastClickLocation, [candidate frame])) {
                screen = candidate;
                break;
            }
        }
        NSRect screenFrame = [screen frame];
        NSRect fallback = NSMakeRect(_lastClickLocation.x - 12.0, NSMaxY(screenFrame) - thickness, 24.0, thickness);
        NSLog(@"Bushfire: Button-Rect %@ passt nicht zum Klick (%@), nutze %@", NSStringFromRect(rect), NSStringFromPoint(_lastClickLocation), NSStringFromRect(fallback));
        rect = fallback;
    }
    else {
        NSLog(@"Bushfire: Status-Button-Rect %@ (Klick: %@)", NSStringFromRect(rect), NSStringFromPoint(_lastClickLocation));
    }
    
    return rect;
}

@end
