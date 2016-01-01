//
//  AppDelegate.m
//  CaseLights
//
//  Created by Thomas Buck on 21.12.15.
//  Copyright © 2015 xythobuz. All rights reserved.
//

#import "AppDelegate.h"
#import "Serial.h"
#import "GPUStats.h"
#import "Screenshot.h"

// These are the values stored persistently in the preferences
#define PREF_SERIAL_PORT @"SerialPort"
#define PREF_LIGHTS_STATE @"LightState"
// LED Mode contains the last selected mode as menu item text
#define PREF_LED_MODE @"LEDMode"
#define PREF_BRIGHTNESS @"Brightness"
#define PREF_COLOR @"ManualColor"

#define TEXT_MANUAL @"Select..."
#define TEXT_CPU_USAGE @"CPU Usage"
#define TEXT_RAM_USAGE @"RAM Usage"
#define TEXT_GPU_USAGE @"GPU Usage"
#define TEXT_VRAM_USAGE @"VRAM Usage"
#define TEXT_CPU_TEMPERATURE @"CPU Temperature"
#define TEXT_GPU_TEMPERATURE @"GPU Temperature"
#define TEXT_RGB_FADE @"RGB Fade"
#define TEXT_HSV_FADE @"HSV Fade"
#define TEXT_RANDOM @"Random"
#define TEXT_TEMPLATE_AUDIO @"AudioDevice_%@"

// SMC keys are checked for existence and used for reading
#define KEY_CPU_TEMPERATURE @"TC0D"
#define KEY_GPU_TEMPERATURE @"TG0D"

// Temperature in Celsius
#define CPU_TEMP_MIN 20
#define CPU_TEMP_MAX 90

// HSV Color (S = V = 1)
#define CPU_COLOR_MIN 120
#define CPU_COLOR_MAX 0

#define GPU_TEMP_MIN 20
#define GPU_TEMP_MAX 90
#define GPU_COLOR_MIN 120
#define GPU_COLOR_MAX 0

#define RAM_COLOR_MIN 0
#define RAM_COLOR_MAX 120

// You can play around with these values (skipped pixels, display timer delay) to change CPU usage in display mode
#define AVERAGE_COLOR_PERFORMANCE_INC 10
#define DISPLAY_DELAY 0.1

// Used to identify selected menu items
// displays are all tags >= 0
#define MENU_ITEM_TAG_NOTHING -1
#define MENU_ITEM_TAG_AUDIO -2

@interface AppDelegate ()

@property (strong) NSStatusItem *statusItem;
@property (strong) NSImage *statusImage;
@property (strong) NSDictionary *staticColors;
@property (strong) NSTimer *animation;
@property (strong) Serial *serial;
@property (strong) NSMenuItem *lastLEDMode;
@property (strong) EZMicrophone *microphone;

@end

@implementation AppDelegate

@synthesize statusMenu, application;
@synthesize menuColors, menuAnimations, menuVisualizations, menuPorts;
@synthesize menuItemDisplays, menuDisplays;
@synthesize menuItemAudio, menuAudio;
@synthesize buttonOff, buttonLights;
@synthesize brightnessItem, brightnessSlider, brightnessLabel;
@synthesize statusItem, statusImage;
@synthesize staticColors, animation;
@synthesize serial, lastLEDMode, microphone;
@synthesize menuItemColor;

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    srand((unsigned)time(NULL));
    
    serial = [[Serial alloc] init];
    lastLEDMode = nil;
    animation = nil;
    microphone = nil;
    
    // Prepare status bar menu
    statusImage = [NSImage imageNamed:@"MenuIcon"];
    [statusImage setTemplate:YES];
    statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSSquareStatusItemLength];
    [statusItem setImage:statusImage];
    [statusItem setMenu:statusMenu];
    
    // Set default configuration values, load existing ones
    NSUserDefaults *store = [NSUserDefaults standardUserDefaults];
    NSMutableDictionary *appDefaults = [NSMutableDictionary dictionaryWithObject:@"" forKey:PREF_SERIAL_PORT];
    [appDefaults setObject:[NSNumber numberWithBool:NO] forKey:PREF_LIGHTS_STATE];
    [appDefaults setObject:@"" forKey:PREF_LED_MODE];
    [appDefaults setObject:[NSNumber numberWithFloat:50.0] forKey:PREF_BRIGHTNESS];
    [store registerDefaults:appDefaults];
    [store synchronize];
    NSString *savedPort = [store stringForKey:PREF_SERIAL_PORT];
    BOOL turnOnLights = [store boolForKey:PREF_LIGHTS_STATE];
    NSString *lastMode = [store stringForKey:PREF_LED_MODE];
    float brightness = [store floatForKey:PREF_BRIGHTNESS];
    NSData *lastColorData = [store dataForKey:PREF_COLOR];
    NSColor *lastColor = nil;
    if (lastColorData != nil) {
        lastColor = (NSColor *)[NSUnarchiver unarchiveObjectWithData:lastColorData];
    }
    
    // Prepare brightness menu
    brightnessItem.view = brightnessSlider;
    [brightnessSlider setFloatValue:brightness];
    [brightnessLabel setTitle:[NSString stringWithFormat:@"Value: %.0f%%", brightness]];
    
    // Prepare serial port menu
    NSArray *ports = [Serial listSerialPorts];
    if ([ports count] > 0) {
        [menuPorts removeAllItems];
        for (int i = 0; i < [ports count]; i++) {
            // Add Menu Item for this port
            NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:[ports objectAtIndex:i] action:@selector(selectedSerialPort:) keyEquivalent:@""];
            [item setTag:MENU_ITEM_TAG_NOTHING];
            [menuPorts addItem:item];
            
            // Set Enabled if it was used the last time
            if ((savedPort != nil) && [[ports objectAtIndex:i] isEqualToString:savedPort]) {
                [[menuPorts itemAtIndex:i] setState:NSOnState];
                
                // Try to open serial port
                [serial setPortName:savedPort];
                if ([serial openPort]) {
                    // Unselect it when an error occured opening the port
                    [[menuPorts itemAtIndex:i] setState:NSOffState];
                }
            }
        }
    }
    
    // Select "Off" button if it was last selected
    if ([lastMode isEqualToString:@""]) {
        [buttonOff setState:NSOffState];
        [self turnLEDsOff:buttonOff];
    }
    
    // Prepare static colors menu
    staticColors = [NSDictionary dictionaryWithObjectsAndKeys:
                    [NSColor colorWithCalibratedRed:1.0f green:0.0f blue:0.0f alpha:0.0f], @"Red",
                    [NSColor colorWithCalibratedRed:0.0f green:1.0f blue:0.0f alpha:0.0f], @"Green",
                    [NSColor colorWithCalibratedRed:0.0f green:0.0f blue:1.0f alpha:0.0f], @"Blue",
                    [NSColor colorWithCalibratedRed:0.0f green:1.0f blue:1.0f alpha:0.0f], @"Cyan",
                    [NSColor colorWithCalibratedRed:1.0f green:0.0f blue:1.0f alpha:0.0f], @"Magenta",
                    [NSColor colorWithCalibratedRed:1.0f green:1.0f blue:0.0f alpha:0.0f], @"Yellow",
                    [NSColor colorWithCalibratedRed:1.0f green:1.0f blue:1.0f alpha:0.0f], @"White",
                    nil];
    for (NSString *key in [staticColors allKeys]) {
        NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:key action:@selector(selectedVisualization:) keyEquivalent:@""];
        [item setTag:MENU_ITEM_TAG_NOTHING];
        if ([key isEqualToString:lastMode]) {
            [self selectedVisualization:item];
        }
        [menuColors addItem:item];
    }
    menuItemColor = [[NSMenuItem alloc] initWithTitle:TEXT_MANUAL action:@selector(setColorSelected:) keyEquivalent:@""];
    if ([lastMode isEqualToString:TEXT_MANUAL]) {
        if (lastColor != nil) {
            // Restore previously set RGB color
            [self setLightsColor:lastColor];
        }
        [menuItemColor setState:NSOnState];
    }
    [menuItemColor setTag:MENU_ITEM_TAG_NOTHING];
    [menuColors addItem:menuItemColor];
    
    // Prepare animations menu
    NSArray *animationStrings = [NSArray arrayWithObjects:
                                 TEXT_RGB_FADE,
                                 TEXT_HSV_FADE,
                                 TEXT_RANDOM,
                                 nil];
    for (NSString *key in animationStrings) {
        NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:key action:@selector(selectedVisualization:) keyEquivalent:@""];
        [item setTag:MENU_ITEM_TAG_NOTHING];
        if ([key isEqualToString:lastMode]) {
            [self selectedVisualization:item];
        }
        [menuAnimations addItem:item];
    }
    
    // Add CPU Usage menu item
    NSMenuItem *cpuUsageItem = [[NSMenuItem alloc] initWithTitle:TEXT_CPU_USAGE action:@selector(selectedVisualization:) keyEquivalent:@""];
    [cpuUsageItem setTag:MENU_ITEM_TAG_NOTHING];
    if ([lastMode isEqualToString:TEXT_CPU_USAGE]) {
        [self selectedVisualization:cpuUsageItem];
    }
    [menuVisualizations addItem:cpuUsageItem];
    
    // Add Memory Usage item
    NSMenuItem *memoryUsageItem = [[NSMenuItem alloc] initWithTitle:TEXT_RAM_USAGE action:@selector(selectedVisualization:) keyEquivalent:@""];
    [memoryUsageItem setTag:MENU_ITEM_TAG_NOTHING];
    if ([lastMode isEqualToString:TEXT_RAM_USAGE]) {
        [self selectedVisualization:memoryUsageItem];
    }
    [menuVisualizations addItem:memoryUsageItem];
    
    // Check if GPU Stats are available, add menu items if so
    NSNumber *usage;
    NSNumber *freeVRAM;
    NSNumber *usedVRAM;
    if ([GPUStats getGPUUsage:&usage freeVRAM:&freeVRAM usedVRAM:&usedVRAM] != 0) {
        NSLog(@"Error reading GPU information\n");
    } else {
        NSMenuItem *itemUsage = [[NSMenuItem alloc] initWithTitle:TEXT_GPU_USAGE action:@selector(selectedVisualization:) keyEquivalent:@""];
        [itemUsage setTag:MENU_ITEM_TAG_NOTHING];
        if ([lastMode isEqualToString:TEXT_GPU_USAGE]) {
            [self selectedVisualization:itemUsage];
        }
        [menuVisualizations addItem:itemUsage];
        
        NSMenuItem *itemVRAM = [[NSMenuItem alloc] initWithTitle:TEXT_VRAM_USAGE action:@selector(selectedVisualization:) keyEquivalent:@""];
        [itemVRAM setTag:MENU_ITEM_TAG_NOTHING];
        if ([lastMode isEqualToString:TEXT_VRAM_USAGE]) {
            [self selectedVisualization:itemVRAM];
        }
        [menuVisualizations addItem:itemVRAM];
    }
    
    // Check available temperatures and add menu items
    JSKSMC *smc = [JSKSMC smc];
    for (int i = 0; i < [[smc workingTempKeys] count]; i++) {
        NSString *key = [smc.workingTempKeys objectAtIndex:i];
        
#ifdef DEBUG
        NSString *name = [smc humanReadableNameForKey:key];
        NSLog(@"Sensor \"%@\": \"%@\"\n", key, name);
#endif

        if ([key isEqualToString:KEY_CPU_TEMPERATURE]) {
            NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:TEXT_CPU_TEMPERATURE action:@selector(selectedVisualization:) keyEquivalent:@""];
            [item setTag:MENU_ITEM_TAG_NOTHING];
            if ([lastMode isEqualToString:TEXT_CPU_TEMPERATURE]) {
                [self selectedVisualization:item];
            }
            [menuVisualizations addItem:item];
        }
        
        if ([key isEqualToString:KEY_GPU_TEMPERATURE]) {
            NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:TEXT_GPU_TEMPERATURE action:@selector(selectedVisualization:) keyEquivalent:@""];
            [item setTag:MENU_ITEM_TAG_NOTHING];
            if ([lastMode isEqualToString:TEXT_GPU_TEMPERATURE]) {
                [self selectedVisualization:item];
            }
            [menuVisualizations addItem:item];
        }
    }
    
    // Restore previously used lights configuration
    if (turnOnLights) {
        // Turn on lights
        if ([serial isOpen]) {
            [serial sendString:@"UV 1\n"];
        }
        
        [buttonLights setState:NSOnState];
    } else {
        // Turn off lights
        if ([serial isOpen]) {
            [serial sendString:@"UV 0\n"];
        }
    }
    
    // List available displays and add menu items
    [Screenshot init:self];
    NSArray *displayIDs = [Screenshot listDisplays];
    [self updateDisplayUI:displayIDs];
    
    // List available audio input devices and add menu items
    NSArray *inputDevices = [EZAudioDevice inputDevices];
    [menuAudio removeAllItems];
    for (int i = 0; i < [inputDevices count]; i++) {
        EZAudioDevice *dev = [inputDevices objectAtIndex:i];
        
#ifdef DEBUG
        NSLog(@"Audio input device: \"%@\"\n", [dev name]);
#endif
        
        NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:[dev name] action:@selector(selectedVisualization:) keyEquivalent:@""];
        [item setTag:MENU_ITEM_TAG_AUDIO];
        NSString *lastModeString = [NSString stringWithFormat:TEXT_TEMPLATE_AUDIO, [dev name]];
        if ([lastModeString isEqualToString:lastMode]) {
            [self selectedVisualization:item];
        }
        [menuAudio addItem:item];
    }
    if ([inputDevices count] > 0) {
        [menuItemAudio setHidden:NO];
    }
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
    // Stop previous timer setting
    if (animation != nil) {
        [animation invalidate];
        animation = nil;
    }
    
    // Stop previous audio data retrieval
    if (microphone != nil) {
        [microphone stopFetchingAudio];
        microphone = nil;
    }
    
    // Remove display callback
    [Screenshot close:self];
    
    // Turn off all lights if possible
    if ([serial isOpen]) {
        [serial sendString:@"RGB 0 0 0\n"];
        [serial sendString:@"UV 0\n"];
        [serial closePort];
    }
}

- (void)clearDisplayUI {
    for (int i = 0; i < [menuDisplays numberOfItems]; i++) {
        if ([[menuDisplays itemAtIndex:i] isEnabled] == YES) {
            // A display configuration is currently selected. Disable the timer
            if (animation != nil) {
                [animation invalidate];
                animation = nil;
            }
        }
    }
    [menuDisplays removeAllItems];
    [menuItemDisplays setHidden:YES];
}

- (void)updateDisplayUI:(NSArray *)displayIDs {
    if ([displayIDs count] > 0) {
        NSUserDefaults *store = [NSUserDefaults standardUserDefaults];
        NSString *lastMode = [store stringForKey:PREF_LED_MODE];
        [menuItemDisplays setHidden:NO];
        for (int i = 0; i < [displayIDs count]; i++) {
            NSString *title = [Screenshot displayNameFromDisplayID:[displayIDs objectAtIndex:i]];
            NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:title
                                                          action:@selector(selectedVisualization:)
                                                   keyEquivalent:@""];
            [item setTag:[[displayIDs objectAtIndex:i] integerValue]];
            if ([title isEqualToString:lastMode]) {
                [self selectedVisualization:item];
            }
            [menuDisplays addItem:item];
        }
    }
}

- (void)setLightsColor:(NSColor *)color {
    CGFloat red, green, blue, alpha;
    [color getRed:&red green:&green blue:&blue alpha:&alpha];
    [self setLightsR:red * 255 G:green * 255 B:blue * 255];
    
    // Stop previous timer setting
    if (animation != nil) {
        [animation invalidate];
        animation = nil;
    }
    
    // Stop previous audio data retrieval
    if (microphone != nil) {
        [microphone stopFetchingAudio];
        microphone = nil;
    }
    
    // Turn off all other LED menu items
    if (menuColors != nil) {
        for (int i = 0; i < [menuColors numberOfItems]; i++) {
            [[menuColors itemAtIndex:i] setState:NSOffState];
        }
    }
    if (menuAnimations != nil) {
        for (int i = 0; i < [menuAnimations numberOfItems]; i++) {
            [[menuAnimations itemAtIndex:i] setState:NSOffState];
        }
    }
    if (menuVisualizations != nil) {
        for (int i = 0; i < [menuVisualizations numberOfItems]; i++) {
            [[menuVisualizations itemAtIndex:i] setState:NSOffState];
        }
    }
    if (menuAudio != nil) {
        for (int i = 0; i < [menuAudio numberOfItems]; i++) {
            [[menuAudio itemAtIndex:i] setState:NSOffState];
        }
    }
    if (menuDisplays != nil) {
        for (int i = 0; i < [menuDisplays numberOfItems]; i++) {
            [[menuDisplays itemAtIndex:i] setState:NSOffState];
        }
    }
    [buttonOff setState:NSOffState];
    [menuItemColor setState:NSOnState];
    
    // Store new manually selected color
    NSUserDefaults *store = [NSUserDefaults standardUserDefaults];
    NSData *data = [NSArchiver archivedDataWithRootObject:color];
    [store setObject:data forKey:PREF_COLOR];
    [store setObject:TEXT_MANUAL forKey:PREF_LED_MODE];
    [store synchronize];
}

- (void)setLightsR:(unsigned char)r G:(unsigned char)g B:(unsigned char)b {
    if ([serial isOpen]) {
        unsigned char red = r * ([brightnessSlider floatValue] / 100.0);
        unsigned char green = g * ([brightnessSlider floatValue] / 100.0);
        unsigned char blue = b * ([brightnessSlider floatValue] / 100.0);
        [serial sendString:[NSString stringWithFormat:@"RGB %d %d %d\n", red, green, blue]];
    } else {
#ifdef DEBUG
        NSLog(@"Trying to send RGB without opened port!\n");
#endif
    }
}

- (IBAction)relistSerialPorts:(id)sender {
    // Refill audio device list
    NSArray *inputDevices = [EZAudioDevice inputDevices];
    [menuAudio removeAllItems];
    for (int i = 0; i < [inputDevices count]; i++) {
        EZAudioDevice *dev = [inputDevices objectAtIndex:i];
        NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:[dev name] action:@selector(selectedVisualization:) keyEquivalent:@""];
        [item setTag:MENU_ITEM_TAG_AUDIO];
        NSString *lastModeString = [NSString stringWithFormat:TEXT_TEMPLATE_AUDIO, [dev name]];
        if ([lastModeString isEqualToString:[[NSUserDefaults standardUserDefaults] stringForKey:PREF_LED_MODE]]) {
            [self selectedVisualization:item];
        }
        [menuAudio addItem:item];
    }
    if ([inputDevices count] > 0) {
        [menuItemAudio setHidden:NO];
    } else {
        [menuItemAudio setHidden:YES];
    }
    
    // Refill port list
    NSArray *ports = [Serial listSerialPorts];
    [menuPorts removeAllItems];
    for (int i = 0; i < [ports count]; i++) {
        // Add Menu Item for this port
        NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:[ports objectAtIndex:i] action:@selector(selectedSerialPort:) keyEquivalent:@""];
        [item setTag:MENU_ITEM_TAG_NOTHING];
        [menuPorts addItem:item];
        
        // Mark it if it is currently open
        if ([serial isOpen]) {
            if ([[ports objectAtIndex:i] isEqualToString:[serial portName]]) {
                [[menuPorts itemAtIndex:i] setState:NSOnState];
            }
        }
    }
}

- (void)setColorSelected:(NSMenuItem *)sender {
    NSColorPanel *cp = [NSColorPanel sharedColorPanel];
    [cp setTarget:self];
    [cp setAction:@selector(colorSelected:)];
    [cp setShowsAlpha:NO];
    [cp setContinuous:NO];
    [cp setMode:NSRGBModeColorPanel];
    
    // Try to restore last manually selected color
    NSUserDefaults *store = [NSUserDefaults standardUserDefaults];
    NSData *lastColorData = [store dataForKey:PREF_COLOR];
    NSColor *lastColor = nil;
    if (lastColorData != nil) {
        lastColor = (NSColor *)[NSUnarchiver unarchiveObjectWithData:lastColorData];
        [cp setColor:lastColor];
    }
    
    [NSApp activateIgnoringOtherApps:YES];
    [application orderFrontColorPanel:cp];
}

- (void)colorSelected:(NSColorPanel *)sender {
    [self setLightsColor:[sender color]];
}

- (IBAction)brightnessMoved:(NSSlider *)sender {
    [brightnessLabel setTitle:[NSString stringWithFormat:@"Value: %.0f%%", [sender floatValue]]];
    
    // Restore the current configuration for items where it won't happen automatically
    for (int i = 0; i < [menuColors numberOfItems]; i++) {
        if ([[menuColors itemAtIndex:i] state] == NSOnState) {
            [self selectedVisualization:[menuColors itemAtIndex:i]];
        }
    }
    
    // Store changed value in preferences
    NSUserDefaults *store = [NSUserDefaults standardUserDefaults];
    [store setObject:[NSNumber numberWithFloat:[sender floatValue]] forKey:PREF_BRIGHTNESS];
    [store synchronize];
}

- (IBAction)turnLEDsOff:(NSMenuItem *)sender {
    if ([sender state] == NSOffState) {
        lastLEDMode = nil;
        
        // Stop previous timer setting
        if (animation != nil) {
            [animation invalidate];
            animation = nil;
        }
        
        // Stop previous audio data retrieval
        if (microphone != nil) {
            [microphone stopFetchingAudio];
            microphone = nil;
        }

        // Turn off all other LED menu items
        for (int i = 0; i < [menuColors numberOfItems]; i++) {
            if ([[menuColors itemAtIndex:i] state] == NSOnState) {
                lastLEDMode = [menuColors itemAtIndex:i];
            }
            [[menuColors itemAtIndex:i] setState:NSOffState];
        }
        for (int i = 0; i < [menuAnimations numberOfItems]; i++) {
            if ([[menuAnimations itemAtIndex:i] state] == NSOnState) {
                lastLEDMode = [menuAnimations itemAtIndex:i];
            }
            [[menuAnimations itemAtIndex:i] setState:NSOffState];
        }
        for (int i = 0; i < [menuVisualizations numberOfItems]; i++) {
            if ([[menuVisualizations itemAtIndex:i] state] == NSOnState) {
                lastLEDMode = [menuVisualizations itemAtIndex:i];
            }
            [[menuVisualizations itemAtIndex:i] setState:NSOffState];
        }
        for (int i = 0; i < [menuAudio numberOfItems]; i++) {
            if ([[menuAudio itemAtIndex:i] state] == NSOnState) {
                lastLEDMode = [menuAudio itemAtIndex:i];
            }
            [[menuAudio itemAtIndex:i] setState:NSOffState];
        }
        for (int i = 0; i < [menuDisplays numberOfItems]; i++) {
            if ([[menuDisplays itemAtIndex:i] state] == NSOnState) {
                lastLEDMode = [menuDisplays itemAtIndex:i];
            }
            [[menuDisplays itemAtIndex:i] setState:NSOffState];
        }
        
        // Turn on "off" menu item
        [sender setState:NSOnState];
        
        // Store changed value in preferences
        NSUserDefaults *store = [NSUserDefaults standardUserDefaults];
        [store setObject:@"" forKey:PREF_LED_MODE];
        [store synchronize];
        
#ifdef DEBUG
        NSLog(@"Stored new mode: \"off\"!\n");
#endif
        
        // Send command to turn off LEDs
        [self setLightsR:0 G:0 B:0];
    } else {
        // Try to restore last LED setting
        if (lastLEDMode != nil) {
            [self selectedVisualization:lastLEDMode];
        }
    }
}

- (IBAction)toggleLights:(NSMenuItem *)sender {
    if ([sender state] == NSOffState) {
        // Turn on lights
        if ([serial isOpen]) {
            [serial sendString:@"UV 1\n"];
        }
        
        [sender setState:NSOnState];
    } else {
        // Turn off lights
        if ([serial isOpen]) {
            [serial sendString:@"UV 0\n"];
        }
        
        [sender setState:NSOffState];
    }
    
    // Store changed value in preferences
    NSUserDefaults *store = [NSUserDefaults standardUserDefaults];
    [store setBool:([sender state] == NSOnState) forKey:PREF_LIGHTS_STATE];
    [store synchronize];
}

- (BOOL)timedVisualization:(NSString *)mode {
    // Stop previous timer setting
    if (animation != nil) {
        [animation invalidate];
        animation = nil;
    }
    
    // Stop previous audio data retrieval
    if (microphone != nil) {
        [microphone stopFetchingAudio];
        microphone = nil;
    }
    
    // Schedule next invocation for this animation...
    if ([mode isEqualToString:TEXT_GPU_USAGE]) {
        animation = [NSTimer scheduledTimerWithTimeInterval:2.0 target:self selector:@selector(visualizeGPUUsage:) userInfo:mode repeats:YES];
    } else if ([mode isEqualToString:TEXT_VRAM_USAGE]) {
        animation = [NSTimer scheduledTimerWithTimeInterval:2.0 target:self selector:@selector(visualizeVRAMUsage:) userInfo:mode repeats:YES];
    } else if ([mode isEqualToString:TEXT_CPU_USAGE]) {
        animation = [NSTimer scheduledTimerWithTimeInterval:2.0 target:self selector:@selector(visualizeCPUUsage:) userInfo:mode repeats:YES];
    } else if ([mode isEqualToString:TEXT_RAM_USAGE]) {
        animation = [NSTimer scheduledTimerWithTimeInterval:20.0 target:self selector:@selector(visualizeRAMUsage:) userInfo:mode repeats:YES];
    } else if ([mode isEqualToString:TEXT_CPU_TEMPERATURE]) {
        animation = [NSTimer scheduledTimerWithTimeInterval:2.0 target:self selector:@selector(visualizeCPUTemperature:) userInfo:mode repeats:YES];
    } else if ([mode isEqualToString:TEXT_GPU_TEMPERATURE]) {
        animation = [NSTimer scheduledTimerWithTimeInterval:2.0 target:self selector:@selector(visualizeGPUTemperature:) userInfo:mode repeats:YES];
    } else if ([mode isEqualToString:TEXT_RGB_FADE]) {
        animation = [NSTimer scheduledTimerWithTimeInterval:0.1 target:self selector:@selector(visualizeRGBFade:) userInfo:mode repeats:YES];
    } else if ([mode isEqualToString:TEXT_HSV_FADE]) {
        animation = [NSTimer scheduledTimerWithTimeInterval:0.1 target:self selector:@selector(visualizeHSVFade:) userInfo:mode repeats:YES];
    } else if ([mode isEqualToString:TEXT_RANDOM]) {
        animation = [NSTimer scheduledTimerWithTimeInterval:0.25 target:self selector:@selector(visualizeRandom:) userInfo:mode repeats:YES];
    } else {
        return NO;
    }
    
#ifdef DEBUG
    NSLog(@"Scheduled animation for \"%@\"!\n", mode);
#endif
    
    // ...and also execute it right now
    [animation fire];
    return YES;
}

- (void)displayVisualization:(NSMenuItem *)sender {
    // Stop previous timer setting
    if (animation != nil) {
        [animation invalidate];
        animation = nil;
    }
    
    // Stop previous audio data retrieval
    if (microphone != nil) {
        [microphone stopFetchingAudio];
        microphone = nil;
    }
    
    // Schedule next invocation for this animation...
    animation = [NSTimer scheduledTimerWithTimeInterval:DISPLAY_DELAY target:self selector:@selector(visualizeDisplay:) userInfo:[NSNumber numberWithInteger:[sender tag]] repeats:YES];
    
    // ...and also execute it right now
    [animation fire];
}

- (void)selectedVisualization:(NSMenuItem *)sender {
    // Turn off all other LED menu items
    if (menuColors != nil) {
        for (int i = 0; i < [menuColors numberOfItems]; i++) {
            [[menuColors itemAtIndex:i] setState:NSOffState];
        }
    }
    if (menuAnimations != nil) {
        for (int i = 0; i < [menuAnimations numberOfItems]; i++) {
            [[menuAnimations itemAtIndex:i] setState:NSOffState];
        }
    }
    if (menuVisualizations != nil) {
        for (int i = 0; i < [menuVisualizations numberOfItems]; i++) {
            [[menuVisualizations itemAtIndex:i] setState:NSOffState];
        }
    }
    if (menuAudio != nil) {
        for (int i = 0; i < [menuAudio numberOfItems]; i++) {
            [[menuAudio itemAtIndex:i] setState:NSOffState];
        }
    }
    if (menuDisplays != nil) {
        for (int i = 0; i < [menuDisplays numberOfItems]; i++) {
            [[menuDisplays itemAtIndex:i] setState:NSOffState];
        }
    }
    [buttonOff setState:NSOffState];
    [sender setState:NSOnState];
    
    // Check if it is a display
    BOOL found = NO;
    if ([sender tag] > MENU_ITEM_TAG_NOTHING) {
        found = YES;
        [self displayVisualization:sender];
    }
    
    // Check if it is an audio input device
    if ((found == NO) && ([sender tag] == MENU_ITEM_TAG_AUDIO)) {
        found = YES;
        BOOL foundDev = NO;
        NSArray *audioDevices = [EZAudioDevice inputDevices];
        for (int  i = 0; i < [audioDevices count]; i++) {
            EZAudioDevice *dev = [audioDevices objectAtIndex:i];
            if ([[dev name] isEqualToString:[sender title]]) {
                // Found device
                foundDev = YES;
                if (microphone != nil) {
                    [microphone stopFetchingAudio];
                    microphone = nil;
                }
                microphone = [EZMicrophone microphoneWithDelegate:self];
                [microphone setDevice:dev];
                [microphone startFetchingAudio];
                break;
            }
        }
        if (foundDev == NO) {
            NSLog(@"Couldn't find device \"%@\"\n", [sender title]);
            [sender setState:NSOffState];
            return; // Don't store new mode
        }
    }
    
    // Check if it is the manual color select item
    if ((found == NO) && ([sender.title isEqualToString:TEXT_MANUAL])) {
        found = YES;
        [self colorSelected:[NSColorPanel sharedColorPanel]];
    }
    
    // Check if a static color was selected
    if ((found == NO) && (staticColors != nil)) {
        for (NSString *key in [staticColors allKeys]) {
            if ([sender.title isEqualToString:key]) {
                found = YES;
                
                // Stop previous timer setting
                if (animation != nil) {
                    [animation invalidate];
                    animation = nil;
                }
                
                // Stop previous audio data retrieval
                if (microphone != nil) {
                    [microphone stopFetchingAudio];
                    microphone = nil;
                }
                
                NSColor *color = [staticColors valueForKey:key];
                unsigned char red = [color redComponent] * 255;
                unsigned char green = [color greenComponent] * 255;
                unsigned char blue = [color blueComponent] * 255;
                [self setLightsR:red G:green B:blue];
                
                break;
            }
        }
    }
    
    if (found == NO) {
        // Check if an animated visualization was selected
        if ([self timedVisualization:[sender title]] == NO) {
            NSLog(@"Unknown LED Visualization selected!\n");
            return;
        }
    }
    
    // Store changed value in preferences
    NSUserDefaults *store = [NSUserDefaults standardUserDefaults];
    if ([sender tag] == MENU_ITEM_TAG_AUDIO) {
        // Prepend text for audio device names
        NSString *tmp = [NSString stringWithFormat:TEXT_TEMPLATE_AUDIO, [sender title]];
        [store setObject:tmp forKey:PREF_LED_MODE];
    } else {
        [store setObject:[sender title] forKey:PREF_LED_MODE];
    }
    [store synchronize];
    
#ifdef DEBUG
    NSLog(@"Stored new mode: \"%@\"!\n", [sender title]);
#endif
}

- (void)selectedSerialPort:(NSMenuItem *)source {
    // Store selection for next start-up
    NSUserDefaults *store = [NSUserDefaults standardUserDefaults];
    [store setObject:[source title] forKey:PREF_SERIAL_PORT];
    [store synchronize];
    
    // De-select all other ports
    for (int i = 0; i < [menuPorts numberOfItems]; i++) {
        [[menuPorts itemAtIndex:i] setState:NSOffState];
    }
    
    // Select only the current port
    [source setState:NSOnState];
    
    // Close previously opened port, if any
    if ([serial isOpen]) {
        [serial closePort];
    }
    
    // Try to open selected port
    [serial setPortName:[source title]];
    if ([serial openPort] != 0) {
        [source setState:NSOffState];
    } else {
        // Restore the current configuration
        for (int i = 0; i < [menuColors numberOfItems]; i++) {
            if ([[menuColors itemAtIndex:i] state] == NSOnState) {
                [self selectedVisualization:[menuColors itemAtIndex:i]];
            }
        }
        for (int i = 0; i < [menuAnimations numberOfItems]; i++) {
            if ([[menuAnimations itemAtIndex:i] state] == NSOnState) {
                [self selectedVisualization:[menuAnimations itemAtIndex:i]];
            }
        }
        for (int i = 0; i < [menuVisualizations numberOfItems]; i++) {
            if ([[menuVisualizations itemAtIndex:i] state] == NSOnState) {
                [self selectedVisualization:[menuVisualizations itemAtIndex:i]];
            }
        }
        for (int i = 0; i < [menuAudio numberOfItems]; i++) {
            if ([[menuAudio itemAtIndex:i] state] == NSOnState) {
                [self selectedVisualization:[menuAudio itemAtIndex:i]];
            }
        }
        for (int i = 0; i < [menuDisplays numberOfItems]; i++) {
            if ([[menuDisplays itemAtIndex:i] state] == NSOnState) {
                [self selectedVisualization:[menuDisplays itemAtIndex:i]];
            }
        }
        if ([buttonOff state] == NSOnState) {
            [buttonOff setState:NSOffState];
            [self turnLEDsOff:buttonOff];
        }
        if ([buttonLights state] == NSOnState) {
            [serial sendString:@"UV 1\n"];
        } else {
            [serial sendString:@"UV 0\n"];
        }
    }
}

- (IBAction)showAbout:(id)sender {
    [NSApp activateIgnoringOtherApps:YES];
    [application orderFrontStandardAboutPanel:self];
}

- (void)updateBuffer:(float *)buffer withBufferSize:(UInt32)bufferSize {
    if (microphone == nil) {
        return; // Old buffer from before we changed mode
    }
    
    // TODO visualize sound data somehow
    //NSLog(@".");
}

// ------------------------------------------------------
// ----------------- Microphone Delegate ----------------
// ------------------------------------------------------

- (void)microphone:(EZMicrophone *)microphone hasAudioReceived:(float **)buffer withBufferSize:(UInt32)bufferSize withNumberOfChannels:(UInt32)numberOfChannels {
    __weak typeof (self) weakSelf = self;
    
    if (weakSelf.microphone == nil) {
        return;
    }
    
    // Getting audio data as an array of float buffer arrays that can be fed into the
    // EZAudioPlot, EZAudioPlotGL, or whatever visualization you would like to do with
    // the microphone data.
    dispatch_async(dispatch_get_main_queue(),^{
        // buffer[0] = left channel, buffer[1] = right channel
        [weakSelf updateBuffer:buffer[0] withBufferSize:bufferSize];
    });
}

- (void)microphone:(EZMicrophone *)microphone changedDevice:(EZAudioDevice *)device {
    // This is not always guaranteed to occur on the main thread so make sure you
    // wrap it in a GCD block
    dispatch_async(dispatch_get_main_queue(), ^{
        NSLog(@"Changed audio input device: %@", [device name]);
    });
}

// ------------------------------------------------------
// ------------------- Visualizations -------------------
// ------------------------------------------------------

- (void)visualizeDisplay:(NSTimer *)timer {
    NSBitmapImageRep *screen = [Screenshot screenshot:[timer userInfo]];
    NSInteger spp = [screen samplesPerPixel];
    
    if (((spp != 3) && (spp != 4)) || ([screen isPlanar] == YES) || ([screen numberOfPlanes] != 1)) {
        NSLog(@"Unknown image format (%ld, %c, %ld)!\n", (long)spp, ([screen isPlanar] == YES) ? 'p' : 'n', (long)[screen numberOfPlanes]);
        return;
    }
    
    int redC = 0, greenC = 1, blueC = 2;
    if ([screen bitmapFormat] & NSAlphaFirstBitmapFormat) {
        redC = 1; greenC = 2; blueC = 3;
    }
    
    unsigned char *data = [screen bitmapData];
    unsigned long width = [screen pixelsWide];
    unsigned long height = [screen pixelsHigh];
    unsigned long max = width * height;
    unsigned long red = 0, green = 0, blue = 0;
    for (unsigned long i = 0; i < max; i += AVERAGE_COLOR_PERFORMANCE_INC) {
        unsigned long off = spp * i;
        red += data[off + redC];
        green += data[off + greenC];
        blue += data[off + blueC];
    }
    max /= AVERAGE_COLOR_PERFORMANCE_INC;
    [self setLightsR:(red / max) G:(green / max) B:(blue / max)];
}

- (void)visualizeGPUUsage:(NSTimer *)timer {
    NSNumber *usage;
    NSNumber *freeVRAM;
    NSNumber *usedVRAM;
    if ([GPUStats getGPUUsage:&usage freeVRAM:&freeVRAM usedVRAM:&usedVRAM] != 0) {
        NSLog(@"Error reading GPU information\n");
    } else {
        double h = [self map:[usage doubleValue] FromMin:0.0 FromMax:100.0 ToMin:GPU_COLOR_MIN ToMax:GPU_COLOR_MAX];
        
#ifdef DEBUG
        NSLog(@"GPU Usage: %.3f%%\n", [usage doubleValue]);
#endif
        
        unsigned char r, g, b;
        [self convertH:h S:1.0 V:1.0 toR:&r G:&g B:&b];
        [self setLightsR:r G:g B:b];
    }
}

- (void)visualizeVRAMUsage:(NSTimer *)timer {
    NSNumber *usage;
    NSNumber *freeVRAM;
    NSNumber *usedVRAM;
    if ([GPUStats getGPUUsage:&usage freeVRAM:&freeVRAM usedVRAM:&usedVRAM] != 0) {
        NSLog(@"Error reading GPU information\n");
    } else {
        double h = [self map:[freeVRAM doubleValue] FromMin:0.0 FromMax:([freeVRAM doubleValue] + [usedVRAM doubleValue]) ToMin:RAM_COLOR_MIN ToMax:RAM_COLOR_MAX];
        
#ifdef DEBUG
        NSLog(@"VRAM %.2fGB Free + %.2fGB Used = %.2fGB mapped to color %.2f!\n", [freeVRAM doubleValue] / (1024.0 * 1024.0 * 1024.0), [usedVRAM doubleValue] / (1024.0 * 1024.0 * 1024.0), ([freeVRAM doubleValue] + [usedVRAM doubleValue]) / (1024.0 * 1024.0 * 1024.0), h);
#endif
        
        unsigned char r, g, b;
        [self convertH:h S:1.0 V:1.0 toR:&r G:&g B:&b];
        [self setLightsR:r G:g B:b];
    }
}

- (void)visualizeCPUUsage:(NSTimer *)timer {
    JSKMCPUUsageInfo cpuUsageInfo = [JSKSystemMonitor systemMonitor].cpuUsageInfo;
    
    double h = [self map:cpuUsageInfo.usage FromMin:0.0 FromMax:100.0 ToMin:CPU_COLOR_MIN ToMax:CPU_COLOR_MAX];
    
#ifdef DEBUG
    NSLog(@"CPU Usage: %.3f%%\n", cpuUsageInfo.usage);
#endif
    
    unsigned char r, g, b;
    [self convertH:h S:1.0 V:1.0 toR:&r G:&g B:&b];
    [self setLightsR:r G:g B:b];
}

- (void)visualizeRAMUsage:(NSTimer *)timer {
    JSKMMemoryUsageInfo memoryUsageInfo = [JSKSystemMonitor systemMonitor].memoryUsageInfo;
    
    double h = [self map:memoryUsageInfo.freeMemory FromMin:0.0 FromMax:(memoryUsageInfo.usedMemory + memoryUsageInfo.freeMemory) ToMin:RAM_COLOR_MIN ToMax:RAM_COLOR_MAX];
    
#ifdef DEBUG
    NSLog(@"RAM %.2fGB Free + %.2fGB Used = %.2fGB mapped to color %.2f!\n", memoryUsageInfo.freeMemory / (1024.0 * 1024.0 * 1024.0), memoryUsageInfo.usedMemory / (1024.0 * 1024.0 * 1024.0), (memoryUsageInfo.freeMemory + memoryUsageInfo.usedMemory) / (1024.0 * 1024.0 * 1024.0), h);
#endif
    
    unsigned char r, g, b;
    [self convertH:h S:1.0 V:1.0 toR:&r G:&g B:&b];
    [self setLightsR:r G:g B:b];
}

- (void)visualizeGPUTemperature:(NSTimer *)timer {
    JSKSMC *smc = [JSKSMC smc];
    double temp = [smc temperatureInCelsiusForKey:KEY_GPU_TEMPERATURE];
    
    if (temp > 1000.0) {
        temp /= 1000.0;
    }
    
    if (temp > GPU_TEMP_MAX) {
        temp = GPU_TEMP_MAX;
    }
    
    if (temp < GPU_TEMP_MIN) {
        temp = GPU_TEMP_MIN;
    }
    
    double h = [self map:temp FromMin:GPU_TEMP_MIN FromMax:GPU_TEMP_MAX ToMin:GPU_COLOR_MIN ToMax:GPU_COLOR_MAX];
    
#ifdef DEBUG
    NSLog(@"GPU Temp %.2f mapped to color %.2f!\n", temp, h);
#endif
    
    unsigned char r, g, b;
    [self convertH:h S:1.0 V:1.0 toR:&r G:&g B:&b];
    [self setLightsR:r G:g B:b];
}

- (void)visualizeCPUTemperature:(NSTimer *)timer {
    JSKSMC *smc = [JSKSMC smc];
    double temp = [smc temperatureInCelsiusForKey:KEY_CPU_TEMPERATURE];
    
    if (temp > 1000.0) {
        temp /= 1000.0;
    }
    
    if (temp > CPU_TEMP_MAX) {
        temp = CPU_TEMP_MAX;
    }
    
    if (temp < CPU_TEMP_MIN) {
        temp = CPU_TEMP_MIN;
    }
    
    double h = [self map:temp FromMin:CPU_TEMP_MIN FromMax:CPU_TEMP_MAX ToMin:CPU_COLOR_MIN ToMax:CPU_COLOR_MAX];
    
#ifdef DEBUG
    NSLog(@"CPU Temp %.2f mapped to color %.2f!\n", temp, h);
#endif
    
    unsigned char r, g, b;
    [self convertH:h S:1.0 V:1.0 toR:&r G:&g B:&b];
    [self setLightsR:r G:g B:b];
}

- (void)visualizeRGBFade:(NSTimer *)timer {
    static unsigned char color[3] = { 255, 0, 0 };
    static int dec = 0;
    static int val = 0;
    
    // Adapted from:
    // https://gist.github.com/jamesotron/766994
    
    if (dec < 3) {
        int inc = (dec == 2) ? 0 : (dec + 1);
        if (val < 255) {
            color[dec] -= 1;
            color[inc] += 1;
            val++;
        } else {
            val = 0;
            dec++;
        }
    } else {
        dec = 0;
    }
    [self setLightsR:color[0] G:color[1] B:color[2]];
}

- (void)visualizeHSVFade:(NSTimer *)timer {
    static float h = 0.0;
    
    if (h < 359.0) {
        h += 0.5;
    } else {
        h = 0.0;
    }
    
    unsigned char r, g, b;
    [self convertH:h S:1.0 V:1.0 toR:&r G:&g B:&b];
    [self setLightsR:r G:g B:b];
}

- (void)visualizeRandom:(NSTimer *)timer {
    [self setLightsR:rand() % 256 G:rand() % 256 B:rand() % 256];
}

// -----------------------------------------------------
// --------------------- Utilities ---------------------
// -----------------------------------------------------

- (double)map:(double)val FromMin:(double)fmin FromMax:(double)fmax ToMin:(double)tmin ToMax:(double)tmax {
    double norm = (val - fmin) / (fmax - fmin);
    return (norm * (tmax - tmin)) + tmin;
}

- (void)convertH:(double)h S:(double)s V:(double)v toR:(unsigned char *)r G:(unsigned char *)g B:(unsigned char *)b {
    // Adapted from:
    // https://gist.github.com/hdznrrd/656996
    
    if (s == 0.0) {
        // Achromatic
        *r = *g = *b = (unsigned char)(v * 255);
        return;
    }
    
    h /= 60; // sector 0 to 5
    int i = floor(h);
    double f = h - i; // factorial part of h
    double p = v * (1 - s);
    double q = v * (1 - s * f);
    double t = v * (1 - s * (1 - f));
    
    switch (i) {
        case 0:
            *r = (unsigned char)round(255 * v);
            *g = (unsigned char)round(255 * t);
            *b = (unsigned char)round(255 * p);
            break;
            
        case 1:
            *r = (unsigned char)round(255 * q);
            *g = (unsigned char)round(255 * v);
            *b = (unsigned char)round(255 * p);
            break;
            
        case 2:
            *r = (unsigned char)round(255 * p);
            *g = (unsigned char)round(255 * v);
            *b = (unsigned char)round(255 * t);
            break;
            
        case 3:
            *r = (unsigned char)round(255 * p);
            *g = (unsigned char)round(255 * q);
            *b = (unsigned char)round(255 * v);
            break;
            
        case 4:
            *r = (unsigned char)round(255 * t);
            *g = (unsigned char)round(255 * p);
            *b = (unsigned char)round(255 * v);
            break;
            
        default: case 5:
            *r = (unsigned char)round(255 * v);
            *g = (unsigned char)round(255 * p);
            *b = (unsigned char)round(255 * q);
            break;
    }
}

@end
