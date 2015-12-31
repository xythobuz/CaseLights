//
//  AppDelegate.h
//  CaseLights
//
//  Created by Thomas Buck on 21.12.15.
//  Copyright © 2015 xythobuz. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class Serial;

@interface AppDelegate : NSObject <NSApplicationDelegate>

@property (weak) IBOutlet NSMenu *statusMenu;
@property (weak) IBOutlet NSApplication *application;

@property (weak) IBOutlet NSMenu *menuColors;
@property (weak) IBOutlet NSMenu *menuAnimations;
@property (weak) IBOutlet NSMenu *menuVisualizations;
@property (weak) IBOutlet NSMenuItem *menuItemDisplays;
@property (weak) IBOutlet NSMenu *menuDisplays;
@property (weak) IBOutlet NSMenu *menuPorts;

@property (weak) IBOutlet NSMenuItem *buttonOff;
@property (weak) IBOutlet NSMenuItem *brightnessItem;
@property (weak) IBOutlet NSSlider *brightnessSlider;
@property (weak) IBOutlet NSMenuItem *brightnessLabel;
@property (weak) IBOutlet NSMenuItem *buttonLights;

@property (strong) NSMenuItem *menuItemColor;

- (void)clearDisplayUI;
- (void)updateDisplayUI:(NSArray *)displayIDs;

@end

