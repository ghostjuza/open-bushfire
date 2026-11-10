// Hinweis: Der Name bleibt aus Kompatibilitaetsgruenden erhalten. Die Klasse kapselt jetzt
// den NSStatusItem-Button (statusItem.view ist seit macOS 10.14 deprecated und wird unter
// macOS 11 falsch dargestellt/positioniert).
@interface StatusItemView : NSObject {
    NSPoint        _lastClickLocation;
    NSTimeInterval _lastClickTime;
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
