#import "ImagePreviewCell.h"

#define TRACKING_AREA 1
#define PADDING_BEFORE_IMAGE 12.0
#define PADDING_BETWEEN_TITLE_AND_IMAGE 6.0
#define VERTICAL_PADDING_FOR_IMAGE 8.0
#define INFO_IMAGE_SIZE 13.0
#define PADDING_AROUND_INFO_IMAGE 2.0
#define IMAGE_SIZE 15.0


@interface ImagePreviewCell()

@property (nonatomic, retain) NSImage *a_image;

@end

@implementation ImagePreviewCell
@synthesize a_image = _a_image;


- (id)initWithCoder:(NSCoder *)aDecoder
{
    
    self = [super initWithCoder:aDecoder];
    return self;
}

- (id)copyWithZone:(NSZone *)zone
{
    ImagePreviewCell *result = [super copyWithZone:zone];
    
    if ( result != nil )
    {
        result->_a_image = nil;
        [result setImage:[self image]];
    }
    return result;
}


- (void)dealloc
{
    
    [_a_image release];
    [super dealloc];
}


- (NSImage *)image
{
    return self.a_image;
}


- (void)setImage:(NSImage *)image
{
    
    if ( image != _a_image )
    {
        [_a_image release];
        _a_image = [image retain];
    }
}


- (NSRect)imageRectForBounds:(NSRect)bounds
{
    
    NSRect result = bounds;
    result.origin.y += VERTICAL_PADDING_FOR_IMAGE;
    result.origin.x += PADDING_BEFORE_IMAGE;
    
    if ( self.a_image != nil )
    { 
        // Take the actual image and center it in the result
        result.size = [self.a_image size];
        CGFloat widthCenter = IMAGE_SIZE - NSWidth(result);
        
        if ( widthCenter > 0 )
        {
            result.origin.x += round(widthCenter / 2.0);
        }
        CGFloat heightCenter = IMAGE_SIZE - NSHeight(result);
        
        if ( heightCenter > 0 )
        {
            result.origin.y += round(heightCenter / 2.0);
        }
    } 
    else 
    {
        result.size.width = result.size.height = IMAGE_SIZE;
    }
    return result;
}


- (NSRect)titleRectForBounds:(NSRect)bounds
{
    NSAttributedString *title = [self attributedStringValue];
    NSRect result = bounds;
    
    result.origin.x += PADDING_BEFORE_IMAGE + IMAGE_SIZE + PADDING_BETWEEN_TITLE_AND_IMAGE;
    result.origin.y += VERTICAL_PADDING_FOR_IMAGE-1;
    
    if ( title != nil ) {
        result.size = [title size];
    } 
    else {
        result.size = NSZeroSize;
    }
    
    result.size.width = NSWidth(result) + 20;
    return result;
}


- (void)drawInteriorWithFrame:(NSRect)bounds inView:(NSView *)controlView
{
    
    NSImage *backgroundImage = [NSImage imageNamed:@"btn_popup_middle"];
    [backgroundImage setFlipped:[controlView isFlipped]];
    [backgroundImage drawInRect:bounds fromRect:NSZeroRect operation:NSCompositeCopy fraction:0.7];
    
    NSRect imageRect = [self imageRectForBounds:bounds];
    
    if ( self.a_image != nil )
    {
        [self.a_image setFlipped:[controlView isFlipped]];
        [self.a_image drawInRect:imageRect fromRect:NSZeroRect operation:NSCompositeCopy fraction:1.0];
    } 
    else
    {
        NSBezierPath *path = [NSBezierPath bezierPathWithRect:imageRect];
        CGFloat pattern[2] = { 4.0, 2.0 };
        [path setLineDash:pattern count:2 phase:1.0];
        [path setLineWidth:0];
        [[NSColor grayColor] set];
        [path stroke];
    }

    NSRect titleRect = [self titleRectForBounds:bounds];
    
    NSDictionary *attrs = [NSDictionary dictionaryWithObjectsAndKeys:
                           [NSColor whiteColor], NSForegroundColorAttributeName,
                           [NSFont boldSystemFontOfSize:12], NSFontAttributeName,
                           nil];
    
    NSAttributedString *title = [[[NSAttributedString alloc] initWithString:[self title] attributes:attrs] autorelease];
    
    if ( [title length] > 0 )
    {
        [title drawInRect:titleRect];
    }
}


#if TRACKING_AREA
- (void)mouseEntered:(NSEvent *)event
{
    [(NSControl *)[self controlView] updateCell:self];
}


- (void)mouseExited:(NSEvent *)event
{
    [(NSControl *)[self controlView] updateCell:self];
}
#endif


@end
