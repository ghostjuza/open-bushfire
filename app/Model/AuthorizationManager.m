#import "AuthorizationManager.h"

#include <Security/Authorization.h>

@implementation AuthorizationManager

    static AuthorizationRef authorizationRef = nil;

    + (BOOL) createPrivileges
    {
        if (authorizationRef != nil) {
            return YES;
        }

        OSStatus status = AuthorizationCreate(nil, kAuthorizationEmptyEnvironment, kAuthorizationFlagDefaults, &authorizationRef);
        
        if (status != errAuthorizationSuccess)
        {
            NSLog(@"Error Creating Authorization: %d", status);
            return NO;
        }
        
        AuthorizationItem   right  = {kAuthorizationRightExecute, 0, nil, 0};
        AuthorizationRights rights = {1, &right};
        AuthorizationFlags  flags  = kAuthorizationFlagDefaults | kAuthorizationFlagInteractionAllowed | kAuthorizationFlagPreAuthorize | kAuthorizationFlagExtendRights;
        
        status = AuthorizationCopyRights(authorizationRef, &rights, nil, flags, nil);
        
        if (status != errAuthorizationSuccess)
        {
            NSLog(@"Error Authorization Unsuccessful: %d", status);
            return NO;
        }
        
        return YES;
    }

    + (BOOL) createDirectoryAtPath: (NSString*) path
    {
        if (![self createPrivileges]) {
            return NO;
        }
        
        char *tool   = "/bin/mkdir";
        char *args[] = {(char *)[path UTF8String], nil};
        FILE *pipe   = nil;
        
        OSStatus status = AuthorizationExecuteWithPrivileges(authorizationRef, tool, kAuthorizationFlagDefaults, args, &pipe);

        if (status != errAuthorizationSuccess)
        {
            NSLog(@"Error Create Directory: %d", status);
            return NO;
        }
        
        return YES;
    }

    + (BOOL) removeFile: (NSString*) file
    {
        if (![self createPrivileges]) {
            return NO;
        }

        char *tool   = "/bin/rm";
        char *args[] = {(char *)[file UTF8String], nil};
        FILE *pipe   = nil;

        OSStatus status = AuthorizationExecuteWithPrivileges(authorizationRef, tool, kAuthorizationFlagDefaults, args, &pipe);

        if (status != errAuthorizationSuccess) {
            NSLog(@"Error remove file: %d", status);
            return NO;
        }

        return YES;
    }

    + (BOOL) moveFileAtPath: (NSString*) fromPath toPath: (NSString*) toPath asCopy: (bool) asCopy
    {
        if (![self createPrivileges]) {
            return NO;
        }

        char *mode = "copy";
        char *tool = "/bin/cp";

        if (!asCopy)
        {
            mode = "move";
            tool = "/bin/mv";
        }

        char *args[] = {(char *)[fromPath UTF8String], (char *)[toPath UTF8String], nil};
        FILE *pipe   = nil;
        
        OSStatus status = AuthorizationExecuteWithPrivileges(authorizationRef, tool, kAuthorizationFlagDefaults, args, &pipe);
        
        if (status != errAuthorizationSuccess)
        {
            NSLog(@"Error %s file: %d", mode, status);
            return NO;
        }

        NSFileManager *fileManager = [NSFileManager defaultManager];

        do {
            #if DEBUG == 1
                NSLog(@"[DBG] Waiting for %s file: %s %s", mode, (char *)[fromPath UTF8String], (char *)[toPath UTF8String]);
            #endif
            [NSThread sleepForTimeInterval:0.5f]; // Must wait (0.5 sec) until the file is copied/moved !!!
        }
        while (![fileManager fileExistsAtPath:toPath]);

        return YES;
    }

    + (BOOL) moveFileAtPath: (NSString*) fromPath toPath: (NSString*) toPath
    {
        return [self moveFileAtPath:fromPath toPath:toPath asCopy:false];
    }

    + (BOOL) moveFolderAtPath: (NSString*) fromPath toPath: (NSString*) toPath
    {
        if (![self createPrivileges]) {
            return NO;
        }

        char *tool   = "/bin/mv"; // // rsync -dura /branch2/media/ /branch1/media/
        char *args[] = {"-f", (char *)[fromPath UTF8String], (char *)[toPath UTF8String], nil};
        FILE *pipe   = nil;
        
        OSStatus status = AuthorizationExecuteWithPrivileges(authorizationRef, tool, kAuthorizationFlagDefaults, args, &pipe);
        
        if (status != errAuthorizationSuccess)
        {
            NSLog(@"Error Move Directory: %d", status);
            return NO;
        }

        NSFileManager *fileManager = [NSFileManager defaultManager];

        do
        {
            #if DEBUG == 1
            
                char *mode = "move";
                NSLog(@"[DBG] Waiting for %s folder: %s %s", mode, (char *)[fromPath UTF8String], (char *)[toPath UTF8String]);
            
            #endif
            
            [NSThread sleepForTimeInterval:0.5f]; // Must wait (0.5 sec) until the folder is moved !!!
        }
        while (![fileManager fileExistsAtPath:toPath]);
        
        return YES;
    }

    + (void) freeAuthorization
    {
        if (authorizationRef != nil)
        {
            AuthorizationFree(authorizationRef, kAuthorizationFlagDestroyRights);
            authorizationRef = nil;
        }
    }

@end
