#import "LineView.h"

@implementation LineView

- (void)drawRect:(NSRect)dirtyRect {
    CGContextRef context = (CGContextRef) [[NSGraphicsContext currentContext] graphicsPort];
    CGContextSetRGBFillColor(context, 0.2,0.2,0.2,0.8);
    CGContextFillRect(context, NSRectToCGRect(dirtyRect));
}

@end
