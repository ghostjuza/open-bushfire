#import "NSButton+TextColor.h"

@implementation NSButton (TextColor)

- (NSColor *)textColor
{
    NSAttributedString *attrTitle = [self attributedTitle];
    NSDictionary *attrs = [attrTitle fontAttributesInRange:NSMakeRange(0, MIN([attrTitle length], 1))];
    NSColor *textColor = [NSColor controlTextColor];
   
    if (attrs) {
        textColor = [attrs objectForKey:NSForegroundColorAttributeName];
    }
    
    return textColor;
}

- (void)setTextColor:(NSColor *)textColor
{
    NSMutableAttributedString *attrTitle = [[NSMutableAttributedString alloc] initWithAttributedString:[self attributedTitle]];
    NSRange range = NSMakeRange(0, [attrTitle length]);
    [attrTitle addAttribute:NSForegroundColorAttributeName value:textColor range:range];
    [attrTitle fixAttributesInRange:range];
    [self setAttributedTitle:attrTitle];
    [attrTitle release];
}

@end
