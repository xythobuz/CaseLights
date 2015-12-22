//
//  AppDelegate.m
//  CaseLights
//
//  Created by Thomas Buck on 21.12.15.
//  Copyright © 2015 xythobuz. All rights reserved.
//

#import "AppDelegate.h"

@interface AppDelegate ()

@end

@implementation AppDelegate

@synthesize statusMenu, statusItem, statusImage;

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    statusImage = [NSImage imageNamed:@"MenuIcon"];
    [statusImage setTemplate:YES];
    
    statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSSquareStatusItemLength];
    [statusItem setImage:statusImage];
    [statusItem setMenu:statusMenu];
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
    // Insert code here to tear down your application
}

@end
