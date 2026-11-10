#import "DarkLineView.h"

@implementation DarkLineView

- (id)initWithFrame:(NSRect)frameRect
{
    if ((self = [super initWithFrame:frameRect])) {
        [self setWantsLayer:YES];
        [[self layer] setBackgroundColor:[[NSColor colorWithCalibratedRed:0.0 green:0.0 blue:0.0 alpha:0.5] CGColor]];
    }
    return self;
}

@end
