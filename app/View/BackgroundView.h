#define ARROW_WIDTH 20
#define ARROW_HEIGHT 10

@interface BackgroundView : NSView

@property (nonatomic, assign) NSInteger arrowX;

- (void)renderBackgroundInContext:(CGContextRef)ctx;   // nur Hintergrund-Layer (Verlauf, Rahmen, Linien) fuer Standbilder

@end
