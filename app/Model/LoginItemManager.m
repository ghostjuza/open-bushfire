#import "LoginItemManager.h"

@implementation LoginItemManager

// Autostart ueber LaunchAgent in ~/Library/LaunchAgents (zuverlaessig unter macOS 11+,
// die alte LSSharedFileList-Anmeldeobjektliste liefert dort unbrauchbare Ergebnisse).
+ (NSString *)launchAgentPath
{
    NSString *label = [[NSBundle mainBundle] bundleIdentifier];
    if ([label length] == 0) label = @"de.bushfire.app";
    NSString *dir = [NSHomeDirectory() stringByAppendingPathComponent:@"Library/LaunchAgents"];
    return [dir stringByAppendingPathComponent:[label stringByAppendingString:@".autostart.plist"]];
}

+ (BOOL)isLaunchAtStartup
{
    return [[NSFileManager defaultManager] fileExistsAtPath:[self launchAgentPath]];
}

+ (void)toggleLaunchAtStartup
{
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *path = [self launchAgentPath];
    
    if ([fm fileExistsAtPath:path]) {
        NSError *error = nil;
        if (![fm removeItemAtPath:path error:&error]) NSLog(@"Bushfire: Autostart entfernen fehlgeschlagen: %@", error);
        return;
    }
    
    NSString *label = [[path lastPathComponent] stringByDeletingPathExtension];
    NSDictionary *plist = [NSDictionary dictionaryWithObjectsAndKeys:
        label, @"Label",
        [NSArray arrayWithObjects:@"/usr/bin/open", @"-a", [[NSBundle mainBundle] bundlePath], nil], @"ProgramArguments",
        [NSNumber numberWithBool:YES], @"RunAtLoad",
        nil];
    
    NSError *error = nil;
    [fm createDirectoryAtPath:[path stringByDeletingLastPathComponent] withIntermediateDirectories:YES attributes:nil error:&error];
    if (![plist writeToFile:path atomically:YES]) NSLog(@"Bushfire: Autostart schreiben fehlgeschlagen: %@", path);
}

@end
