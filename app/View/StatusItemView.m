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
    NSRect itemRect = NSMakeRect(0.0, 0.0, [statusItem length], [[NSStatusBar systemStatusBar] thickness]);
    if ( (self = [super initWithFrame:itemRect]) ) {
        _statusItem = [statusItem retain];
        _statusItem.view = self;
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
- (void)drawRect:(NSRect)dirtyRect
{
	[self.statusItem drawStatusBarBackgroundInRect:dirtyRect withHighlight:self.isHighlighted];
    
    NSImage *icon = self.isHighlighted ? self.alternateImage : self.image;
    CGFloat iconX = roundf((NSWidth(self.bounds) - [icon size].width) / 2);
    CGFloat iconY = roundf((NSHeight(self.bounds) - [icon size].height) / 2);
    NSPoint iconPoint = NSMakePoint(iconX, iconY);
    [icon drawAtPoint:iconPoint fromRect:dirtyRect operation:NSCompositeSourceOver fraction:1];
}

#pragma mark -
#pragma mark Mouse tracking

- (void)mouseDown:(NSEvent *)theEvent
{
    [NSApp sendAction:self.action to:self.target from:self];
}

#pragma mark -
#pragma mark Accessors

- (void)setHighlighted:(BOOL)newFlag
{
    if (_isHighlighted == newFlag) {
        return;
    }
    _isHighlighted = newFlag;
    [self setNeedsDisplay:YES];
}

#pragma mark -


- (void)setImage:(NSImage *)newImage
{
    [newImage retain];
    [_image release];
    _image = newImage;
    [self setNeedsDisplay:YES];
}

- (void)setAlternateImage:(NSImage *)newImage
{
    [newImage retain];
    [_alternateImage release];
    _alternateImage = newImage;
    
    if (self.isHighlighted) {
        [self setNeedsDisplay:YES];
    }   
}

#pragma mark -

- (NSRect)globalRect
{
    NSRect frame = [self frame];
    // convertPointToScreen macht stress bei Mountain Lion
    //frame.origin = [self.window convertBaseToScreen:frame.origin];
    frame.origin = [self.window convertPointToScreen:frame.origin];
    return frame;
}

@end
