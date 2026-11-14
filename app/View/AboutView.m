#import "AboutView.h"

#define CORNER_RADIUS 12.0f


@interface AboutView () {
    NSPoint _dragMouseStart;
    NSPoint _dragWindowStart;
}
@end

@implementation AboutView


// Fenster per Hintergrund verschieben: eigene Implementierung, damit Buttons (Schliessen-Button)
// nicht durch setMovableByWindowBackground die Mausklicks verlieren (macOS 12).
- (BOOL)acceptsFirstMouse:(NSEvent *)event
{
    return YES;
}

- (BOOL)mouseDownCanMoveWindow
{
    return NO;
}

- (void)mouseDown:(NSEvent *)event
{
    _dragMouseStart  = [NSEvent mouseLocation];
    _dragWindowStart = [[self window] frame].origin;
}

- (void)mouseDragged:(NSEvent *)event
{
    NSPoint now = [NSEvent mouseLocation];
    [[self window] setFrameOrigin:NSMakePoint(_dragWindowStart.x + (now.x - _dragMouseStart.x),
                                              _dragWindowStart.y + (now.y - _dragMouseStart.y))];
}


- (void)drawRect:(NSRect)dirtyRect
{
  
    CGFloat colorLocations[5];
    colorLocations[0]= 0.0;
    // feste Abstaende (oberer Auslauf 59 pt, Fusszeile 36 pt), unabhaengig von der Fensterhoehe
    CGFloat viewHeight = MAX(NSHeight([self bounds]), 100.0);
    colorLocations[1]= 59.0 / viewHeight;
    colorLocations[2]= 1.0 - 36.0 / viewHeight;
    colorLocations[3]= 1.0 - 36.0 / viewHeight;
    colorLocations[4]= 1.0;
    
    NSGradient *fillGradient = [[NSGradient alloc] initWithColors:
                                [NSArray arrayWithObjects:
                                 [NSColor colorWithCalibratedWhite:0.2 alpha:.9],
                                 [NSColor colorWithCalibratedWhite:0.1 alpha:.9],
                                 [NSColor colorWithCalibratedWhite:0.1 alpha:.9],
                                 [NSColor colorWithCalibratedWhite:0.15 alpha:.9],
                                 [NSColor colorWithCalibratedWhite:0.1 alpha:.9],
                                 nil]
                                                      atLocations:colorLocations
                                                       colorSpace:[NSColorSpace deviceRGBColorSpace]];
    
    NSRect contentRect = NSInsetRect([self bounds], 1.0, 1.0);
    NSBezierPath *path = [NSBezierPath bezierPathWithRoundedRect:contentRect xRadius:CORNER_RADIUS yRadius:CORNER_RADIUS];
    
    [NSGraphicsContext saveGraphicsState];
    
    [fillGradient drawInBezierPath:path angle:-90.0];
    [fillGradient release];
    
    [NSGraphicsContext restoreGraphicsState];
    
    [[NSColor colorWithDeviceWhite:0.0 alpha:0.6] set];
    [[NSBezierPath bezierPathWithRect:NSMakeRect(1, 36, 296, 1)] fill];
}


@end
