#import "SettingCheckboxCell.h"

@implementation SettingCheckboxCell

- (NSRect)drawTitle:(NSAttributedString *)title withFrame:(NSRect)frame inView:(NSView *)controlView {
    
    NSDictionary *attrs = [NSDictionary dictionaryWithObjectsAndKeys:
                           [NSColor whiteColor], NSForegroundColorAttributeName,
                           [NSFont systemFontOfSize:12], NSFontAttributeName,
                           nil];
    
    NSAttributedString *titleAttr = [[[NSAttributedString alloc] initWithString:[self title] attributes:attrs] autorelease];
    
    NSRect titleRect = [self titleRectForBounds:frame];
    titleRect.origin.x = 20;
    titleRect.origin.y = -2;
    titleRect.size.height = 18;
    
    if ( [titleAttr length] > 0 )
    {
        [titleAttr drawInRect:titleRect];
    }
    
    return titleRect;
}

@end
