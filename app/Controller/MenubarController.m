#import "MenubarController.h"
#import "StatusItemView.h"


@interface MenubarController()

    @property (retain, nonatomic) NSStatusItem *a_statusItem;

@end


@implementation MenubarController

    @synthesize StatusItemView = _StatusItemView;
    @synthesize a_statusItem   = _a_statusItem;

    static NSString *iconName       = @"ico_menubar";
    static NSString *iconNameInvert = @"ico_menubar_invert";
    static NSString *iconNameClean  = @"ico_menubar_clean";


    - (id)init
    {
        NSImage *icon       = [NSImage imageNamed:iconName];
        NSImage *iconInvert = [NSImage imageNamed:iconNameInvert];
        
        if ([self getInterfaceStyle] != nil) {
            icon = [NSImage imageNamed:iconNameInvert];
        }

        if ((self = [super init]))
        {
            NSStatusItem *statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:STATUS_ITEM_VIEW_WIDTH];
            _StatusItemView = [[StatusItemView alloc] initWithStatusItem:statusItem];
            
            _StatusItemView.image = icon;
            _StatusItemView.alternateImage = iconInvert;
            _StatusItemView.action = @selector(togglePanel:);
        }

        return self;
    }

    - (BOOL) isOldBusted
    {
        return (floor(NSAppKitVersionNumber) <= NSAppKitVersionNumber10_9);
    }

    - (void)dealloc
    {
        if (self.a_statusItem != nil) {
            [[NSStatusBar systemStatusBar] removeStatusItem:self.a_statusItem];
        }
        
        [_a_statusItem release];
        [_StatusItemView release];
        [super dealloc];
    }


    #pragma mark -
    #pragma mark Public accessors


    - (NSStatusItem *)statusItem
    {
        return self.StatusItemView.statusItem;
    }


    #pragma mark -

    - (BOOL)hasActiveIcon
    {
        NSImage *icon = [NSImage imageNamed:iconName];
        
        if ([self getInterfaceStyle] != nil) {
            icon = [NSImage imageNamed:iconNameInvert];
        }
        
        if ([self.StatusItemView.image.name isNotEqualTo:iconNameClean]) {
            self.StatusItemView.image = icon;
        }

        return self.StatusItemView.isHighlighted;
    }

    - (void)setCleanIcon
    {
        NSImage *icon = [NSImage imageNamed:iconNameClean];
        self.StatusItemView.image = icon;
    }

    - (void)unsetCleanIcon
    {
        NSImage *icon = [NSImage imageNamed:iconName];
        
        if ([self getInterfaceStyle] != nil) {
            icon = [NSImage imageNamed:iconNameInvert];
        }

        if (!self.isOldBusted) {
            // 10.10 or higher, so setTemplate: is safe
            [icon setTemplate:YES];
        }
        
        self.StatusItemView.image = icon;
    }

    - (void)setHasActiveIcon:(BOOL)flag
    {
        self.StatusItemView.isHighlighted = flag;
    }

    - (NSString*) getInterfaceStyle
    {
        return [[NSUserDefaults standardUserDefaults] stringForKey:@"AppleInterfaceStyle"];
    }

@end
