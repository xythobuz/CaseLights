//
//  AppDelegate.h
//  CaseLights
//
//  Created by Thomas Buck on 21.12.15.
//  Copyright © 2015 xythobuz. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface AppDelegate : NSObject <NSApplicationDelegate>

@property (weak) IBOutlet NSMenu *statusMenu;

@property (weak) IBOutlet NSMenu *menuColors;
@property (weak) IBOutlet NSMenu *menuAnimations;
@property (weak) IBOutlet NSMenu *menuVisualizations;
@property (weak) IBOutlet NSMenu *menuPorts;

@property (weak) IBOutlet NSMenuItem *buttonOff;
@property (weak) IBOutlet NSMenuItem *buttonLights;

@property (strong) NSStatusItem *statusItem;
@property (strong) NSImage *statusImage;

@property (strong) NSDictionary *staticColors;

@end

