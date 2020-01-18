#import "BackgroundView.h"
#import "StatusItemView.h"

@protocol PanelControllerDelegate;


@interface PanelController : NSWindowController <NSWindowDelegate>

@property BOOL hasActivePanel;
@property (nonatomic, readonly) id<PanelControllerDelegate> Delegate;

- (id)initWithDelegate:(id<PanelControllerDelegate>)delegate;

@end


@protocol PanelControllerDelegate <NSObject>

@optional
- (StatusItemView *)statusItemViewForPanelController:(PanelController *)controller;

@end