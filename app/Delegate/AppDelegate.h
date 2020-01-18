#import "MenubarController.h"
#import "PanelController.h"

@interface AppDelegate : NSObject <NSApplicationDelegate, PanelControllerDelegate>

+ (MenubarController*)getMenubarController;

@end
