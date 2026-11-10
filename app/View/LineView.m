#import "LineView.h"

@implementation LineView

- (id)initWithFrame:(NSRect)frameRect
{
    if ((self = [super initWithFrame:frameRect])) {
        [self setWantsLayer:YES];
        [[self layer] setBackgroundColor:[[NSColor colorWithCalibratedRed:0.2 green:0.2 blue:0.2 alpha:0.8] CGColor]];
    }
    return self;
}

@end
