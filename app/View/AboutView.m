#import "AboutView.h"

#define CORNER_RADIUS 6.0f


@implementation AboutView


- (void)drawRect:(NSRect)dirtyRect
{
  
    CGFloat colorLocations[5];
    colorLocations[0]= 0.0;
    colorLocations[1]= 0.25;
    colorLocations[2]= 0.85;
    colorLocations[3]= 0.85;
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
    NSBezierPath *path = [NSBezierPath bezierPath];
    
    [path moveToPoint:NSMakePoint(0, NSMaxY(contentRect))];
    [path lineToPoint:NSMakePoint(0, NSMaxY(contentRect))];
    [path lineToPoint:NSMakePoint(NSMaxX(contentRect) - CORNER_RADIUS, NSMaxY(contentRect))];
    
    NSPoint topRightCorner = NSMakePoint(NSMaxX(contentRect), NSMaxY(contentRect));
    [path curveToPoint:NSMakePoint(NSMaxX(contentRect), NSMaxY(contentRect) - CORNER_RADIUS)
         controlPoint1:topRightCorner controlPoint2:topRightCorner];
    
    [path lineToPoint:NSMakePoint(NSMaxX(contentRect), NSMinY(contentRect) + CORNER_RADIUS)];
    
    NSPoint bottomRightCorner = NSMakePoint(NSMaxX(contentRect), NSMinY(contentRect));
    [path curveToPoint:NSMakePoint(NSMaxX(contentRect) - CORNER_RADIUS, NSMinY(contentRect))
         controlPoint1:bottomRightCorner controlPoint2:bottomRightCorner];
    
    [path lineToPoint:NSMakePoint(NSMinX(contentRect) + CORNER_RADIUS, NSMinY(contentRect))];
    
    [path curveToPoint:NSMakePoint(NSMinX(contentRect), NSMinY(contentRect) + CORNER_RADIUS)
         controlPoint1:contentRect.origin controlPoint2:contentRect.origin];
    
    [path lineToPoint:NSMakePoint(NSMinX(contentRect), NSMaxY(contentRect) - CORNER_RADIUS)];
    
    NSPoint topLeftCorner = NSMakePoint(NSMinX(contentRect), NSMaxY(contentRect));
    [path curveToPoint:NSMakePoint(NSMinX(contentRect) + CORNER_RADIUS, NSMaxY(contentRect))
         controlPoint1:topLeftCorner controlPoint2:topLeftCorner];
    
    [path lineToPoint:NSMakePoint(0, NSMaxY(contentRect))];
    [path closePath];
    
    [NSGraphicsContext saveGraphicsState];
    
    [fillGradient drawInBezierPath:path angle:-90.0];
    [fillGradient release];
    
    [NSGraphicsContext restoreGraphicsState];
    
    [[NSColor colorWithDeviceWhite:0.0 alpha:0.6] set];
    [[NSBezierPath bezierPathWithRect:NSMakeRect(1, 36, 296, 1)] fill];
}


@end
