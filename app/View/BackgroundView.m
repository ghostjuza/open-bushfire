#import <QuartzCore/QuartzCore.h>
#import "BackgroundView.h"

#define LINE_THICKNESS 1.0f
#define CORNER_RADIUS 6.0f

// Das Panel wird mit Core-Animation-Layern gezeichnet (statt drawRect:), weil
// drawRect: auf neueren macOS-Versionen bei layer-backed, transparenten Panels
// nicht zuverlaessig dargestellt wurde.

@interface BackgroundView ()
{
    CAGradientLayer *_gradientLayer;
    CAShapeLayer    *_maskLayer;
    CAShapeLayer    *_borderLayer;
    CALayer         *_lineTopLayer;
    CALayer         *_lineBottomLayer;
}
@end


@implementation BackgroundView
@synthesize arrowX = _arrowX;


- (id)initWithFrame:(NSRect)frameRect
{
    if ((self = [super initWithFrame:frameRect])) {
        [self setWantsLayer:YES];
        [[self layer] setBackgroundColor:[[NSColor clearColor] CGColor]];
        
        _gradientLayer = [[CAGradientLayer alloc] init];
        _maskLayer     = [[CAShapeLayer alloc] init];
        _borderLayer   = [[CAShapeLayer alloc] init];
        _lineTopLayer    = [[CALayer alloc] init];
        _lineBottomLayer = [[CALayer alloc] init];
        
        _gradientLayer.startPoint = CGPointMake(0.5, 1.0); // oben
        _gradientLayer.endPoint   = CGPointMake(0.5, 0.0); // unten
        _gradientLayer.mask = _maskLayer;
        
        _borderLayer.fillColor   = NULL;
        _borderLayer.strokeColor = [[NSColor colorWithCalibratedWhite:0.33 alpha:1.0] CGColor];
        _borderLayer.lineWidth   = LINE_THICKNESS;
        
        _lineTopLayer.backgroundColor    = [[NSColor colorWithCalibratedWhite:0.0 alpha:0.4] CGColor];
        _lineBottomLayer.backgroundColor = [[NSColor colorWithCalibratedWhite:0.0 alpha:0.6] CGColor];
        
        [[self layer] addSublayer:_gradientLayer];
        [[self layer] addSublayer:_borderLayer];
        [[self layer] addSublayer:_lineTopLayer];
        [[self layer] addSublayer:_lineBottomLayer];
        
        [self updateShapes];
    }
    return self;
}


- (void)dealloc
{
    [_gradientLayer release];
    [_maskLayer release];
    [_borderLayer release];
    [_lineTopLayer release];
    [_lineBottomLayer release];
    [super dealloc];
}


- (BOOL)isOpaque
{
    return NO;
}


- (void)setFrameSize:(NSSize)newSize
{
    [super setFrameSize:newSize];
    [self updateShapes];
}


/**
 baut Form (Pfeil + abgerundetes Rechteck), Farbverlauf, Rahmen und Trennlinien neu auf
 */
- (void)updateShapes
{
    CGFloat w = NSWidth([self bounds]);
    CGFloat h = NSHeight([self bounds]);
    if (w < 1 || h < 1) {
        return;
    }
    
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    
    CGRect content = CGRectInset(CGRectMake(0, 0, w, h), LINE_THICKNESS, LINE_THICKNESS);
    CGFloat minX = CGRectGetMinX(content), maxX = CGRectGetMaxX(content);
    CGFloat minY = CGRectGetMinY(content), maxY = CGRectGetMaxY(content);
    CGFloat ax   = (CGFloat)_arrowX;
    CGFloat r    = CORNER_RADIUS;
    
    // Pfeil darf nicht ueber die abgerundeten Ecken hinausragen
    ax = MAX(minX + r + ARROW_WIDTH / 2, MIN(ax, maxX - r - ARROW_WIDTH / 2));
    
    CGMutablePathRef path = CGPathCreateMutable();
    CGPathMoveToPoint(path, NULL, ax, maxY);
    CGPathAddLineToPoint(path, NULL, ax + ARROW_WIDTH / 2, maxY - ARROW_HEIGHT);
    CGPathAddLineToPoint(path, NULL, maxX - r, maxY - ARROW_HEIGHT);
    CGPathAddQuadCurveToPoint(path, NULL, maxX, maxY - ARROW_HEIGHT, maxX, maxY - ARROW_HEIGHT - r);
    CGPathAddLineToPoint(path, NULL, maxX, minY + r);
    CGPathAddQuadCurveToPoint(path, NULL, maxX, minY, maxX - r, minY);
    CGPathAddLineToPoint(path, NULL, minX + r, minY);
    CGPathAddQuadCurveToPoint(path, NULL, minX, minY, minX, minY + r);
    CGPathAddLineToPoint(path, NULL, minX, maxY - ARROW_HEIGHT - r);
    CGPathAddQuadCurveToPoint(path, NULL, minX, maxY - ARROW_HEIGHT, minX + r, maxY - ARROW_HEIGHT);
    CGPathAddLineToPoint(path, NULL, ax - ARROW_WIDTH / 2, maxY - ARROW_HEIGHT);
    CGPathCloseSubpath(path);
    
    CGRect full = CGRectMake(0, 0, w, h);
    
    _gradientLayer.frame = full;
    _maskLayer.frame     = full;
    _maskLayer.path      = path;
    _maskLayer.fillColor = [[NSColor blackColor] CGColor];
    
    _borderLayer.frame = full;
    _borderLayer.path  = path;
    
    // Farbverlauf: oben 0.2 -> 0.1, Fusszeile (unten 32pt) 0.15
    CGFloat vh = MAX(h, 80.0);
    _gradientLayer.colors = [NSArray arrayWithObjects:
        (id)[[NSColor colorWithCalibratedWhite:0.20 alpha:1.0] CGColor],
        (id)[[NSColor colorWithCalibratedWhite:0.10 alpha:1.0] CGColor],
        (id)[[NSColor colorWithCalibratedWhite:0.10 alpha:1.0] CGColor],
        (id)[[NSColor colorWithCalibratedWhite:0.15 alpha:1.0] CGColor],
        (id)[[NSColor colorWithCalibratedWhite:0.15 alpha:1.0] CGColor],
        nil];
    _gradientLayer.locations = [NSArray arrayWithObjects:
        [NSNumber numberWithDouble:0.0],
        [NSNumber numberWithDouble:33.0 / vh],
        [NSNumber numberWithDouble:(vh - 33.0) / vh],
        [NSNumber numberWithDouble:(vh - 32.0) / vh],
        [NSNumber numberWithDouble:1.0],
        nil];
    
    // Trennlinien unter der Kopfzeile und ueber der Fusszeile
    _lineTopLayer.frame    = CGRectMake(1, h - 44, w - 2, 1);
    _lineBottomLayer.frame = CGRectMake(1, 32, w - 2, 1);
    
    CGPathRelease(path);
    [CATransaction commit];
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
    [self updateShapes];
}

@end
