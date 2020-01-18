#import "DarkLineView.h"

@implementation DarkLineView

- (void)drawRect:(NSRect)dirtyRect {
    CGContextRef context = (CGContextRef) [[NSGraphicsContext currentContext] graphicsPort];
    CGContextSetRGBFillColor(context, 0.0,0.0,0.0,0.5);
    CGContextFillRect(context, NSRectToCGRect(dirtyRect));
}

@end
