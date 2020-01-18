#import "BackgroundView.h"

#define LINE_THICKNESS 1.0f
#define CORNER_RADIUS 6.0f

@implementation BackgroundView
@synthesize arrowX = _arrowX;


#pragma mark -

- (void)drawRect:(NSRect)dirtyRect
{

    CGFloat colorLocations[5];
    colorLocations[0]= 0.0;
    colorLocations[1]= 33/self.bounds.size.height;
    colorLocations[2]= (self.bounds.size.height-32)/self.bounds.size.height;
    colorLocations[3]= (self.bounds.size.height-32)/self.bounds.size.height;
    colorLocations[4]= 1.0;

    NSGradient *fillGradient = [[NSGradient alloc] initWithColors:
                                [NSArray arrayWithObjects:
                                 [NSColor colorWithCalibratedWhite:0.2 alpha:1.0],
                                 [NSColor colorWithCalibratedWhite:0.1 alpha:1.0],
                                 [NSColor colorWithCalibratedWhite:0.1 alpha:1.0],
                                 [NSColor colorWithCalibratedWhite:0.15 alpha:1.0],
                                 [NSColor colorWithCalibratedWhite:0.1 alpha:1.0],
                                 nil]
                                                      atLocations:colorLocations
                                                       colorSpace:[NSColorSpace deviceRGBColorSpace]];
    

    NSRect contentRect = NSInsetRect([self bounds], LINE_THICKNESS, LINE_THICKNESS);
    NSBezierPath *path = [NSBezierPath bezierPath];
    
    [path moveToPoint:NSMakePoint(_arrowX, NSMaxY(contentRect))];
    [path lineToPoint:NSMakePoint(_arrowX + ARROW_WIDTH / 2, NSMaxY(contentRect) - ARROW_HEIGHT)];
    [path lineToPoint:NSMakePoint(NSMaxX(contentRect) - CORNER_RADIUS, NSMaxY(contentRect) - ARROW_HEIGHT)];
    
    NSPoint topRightCorner = NSMakePoint(NSMaxX(contentRect), NSMaxY(contentRect) - ARROW_HEIGHT);
    [path curveToPoint:NSMakePoint(NSMaxX(contentRect), NSMaxY(contentRect) - ARROW_HEIGHT - CORNER_RADIUS)
         controlPoint1:topRightCorner controlPoint2:topRightCorner];
    
    [path lineToPoint:NSMakePoint(NSMaxX(contentRect), NSMinY(contentRect) + CORNER_RADIUS)];
    
    NSPoint bottomRightCorner = NSMakePoint(NSMaxX(contentRect), NSMinY(contentRect));
    [path curveToPoint:NSMakePoint(NSMaxX(contentRect) - CORNER_RADIUS, NSMinY(contentRect))
         controlPoint1:bottomRightCorner controlPoint2:bottomRightCorner];
    
    [path lineToPoint:NSMakePoint(NSMinX(contentRect) + CORNER_RADIUS, NSMinY(contentRect))];
    
    [path curveToPoint:NSMakePoint(NSMinX(contentRect), NSMinY(contentRect) + CORNER_RADIUS)
         controlPoint1:contentRect.origin controlPoint2:contentRect.origin];
    
    [path lineToPoint:NSMakePoint(NSMinX(contentRect), NSMaxY(contentRect) - ARROW_HEIGHT - CORNER_RADIUS)];
    
    NSPoint topLeftCorner = NSMakePoint(NSMinX(contentRect), NSMaxY(contentRect) - ARROW_HEIGHT);
    [path curveToPoint:NSMakePoint(NSMinX(contentRect) + CORNER_RADIUS, NSMaxY(contentRect) - ARROW_HEIGHT)
         controlPoint1:topLeftCorner controlPoint2:topLeftCorner];
    
    [path lineToPoint:NSMakePoint(_arrowX - ARROW_WIDTH / 2, NSMaxY(contentRect) - ARROW_HEIGHT)];
    [path closePath];
    
    [NSGraphicsContext saveGraphicsState];
    
    [fillGradient drawInBezierPath:path angle:-90.0];
    [fillGradient release];
    
    NSBezierPath *clip = [NSBezierPath bezierPathWithRect:[self bounds]];
    [clip appendBezierPath:path];
    [clip addClip];
    
    [path setLineWidth:LINE_THICKNESS * 2];
    [[NSColor darkGrayColor] setStroke];
    [path stroke];
    
    [NSGraphicsContext restoreGraphicsState];
    
    [NSGraphicsContext saveGraphicsState];

    [[NSColor colorWithDeviceWhite:0.0 alpha:0.4] set];
    [[NSBezierPath bezierPathWithRect:NSMakeRect(1, self.bounds.size.height-44, 303, 1)] fill];
    [[NSColor colorWithDeviceWhite:0.0 alpha:0.6] set];
    [[NSBezierPath bezierPathWithRect:NSMakeRect(1, 32, 303, 1)] fill];
    
    [NSGraphicsContext restoreGraphicsState];
}


#pragma mark -
#pragma mark Public accessors

/**
 set position of the arrow
 @param value position
 */
- (void)setArrowX:(NSInteger)value
{
    
    _arrowX = value;
    [self setNeedsDisplay:YES];
}

@end
