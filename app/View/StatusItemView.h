@interface StatusItemView : NSView {
}

- (id)initWithStatusItem:(NSStatusItem *)statusItem;

@property (nonatomic, retain) NSStatusItem *statusItem;
@property (nonatomic, retain) NSImage *image;
@property (nonatomic, retain) NSImage *alternateImage;
@property (nonatomic, setter = setHighlighted:) BOOL isHighlighted;
@property (nonatomic, readonly) NSRect globalRect;
@property (nonatomic) SEL action;
@property (nonatomic, assign) id target;

@end
