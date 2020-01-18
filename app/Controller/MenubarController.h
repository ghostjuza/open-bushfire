#define STATUS_ITEM_VIEW_WIDTH 24.0

@class StatusItemView;

@interface MenubarController : NSObject

@property (nonatomic) BOOL hasActiveIcon;
@property (retain, nonatomic) StatusItemView *StatusItemView;

- (void)setCleanIcon;
- (void)unsetCleanIcon;

@end
