#import "CheckboxCell.h"
#import "Helper.h"


@implementation CheckboxCell


- (NSRect)drawTitle:(NSAttributedString *)title withFrame:(NSRect)frame inView:(NSView *)controlView
{
    NSDictionary *attrs = [NSDictionary dictionaryWithObjectsAndKeys:
                           [NSColor whiteColor], NSForegroundColorAttributeName,
                           [NSFont boldSystemFontOfSize:13], NSFontAttributeName,
                           nil];

    NSAttributedString *titleAttr = [[[NSAttributedString alloc] initWithString:[self title] attributes:attrs] autorelease];
    
    NSRect titleRect = [self titleRectForBounds:frame];
    titleRect.origin.x = 20;
    titleRect.origin.y = -2;
    titleRect.size.height = 18;

    if ( [titleAttr length] > 0 ) {
        [titleAttr drawInRect:titleRect];
    }
    
    return titleRect;
}


- (void)drawImage:(NSImage *)image withFrame:(NSRect)frame inView:(NSView *)controlView {
    
    NSImage *checkbox = nil;
    //NSRect imageRect = [self imageRectForBounds:frame];
    
    if ( [self intValue] ) {
        checkbox = [NSImage imageNamed:@"ckbx_on_default"];
    } 
    else {
        checkbox = [NSImage imageNamed:@"ckbx_default"];
    }
    
    //[checkbox drawInRect:NSMakeRect(0, 0, checkbox.size.width, checkbox.size.height) fromRect:NSZeroRect operation:NSCompositeSourceIn fraction:1.0 respectFlipped:YES hints:nil];
    // setFlipped: ist seit 10.6 deprecated; respectFlipped:YES zeichnet in geflippten wie normalen Views korrekt
    [checkbox drawInRect:NSMakeRect(0, 0, checkbox.size.width, checkbox.size.height)
                fromRect:NSZeroRect
               operation:NSCompositingOperationSourceOver
                fraction:1.0
          respectFlipped:YES
                   hints:nil];
}

@end
