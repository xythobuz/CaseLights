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

#import <SystemInfoKit/SystemInfoKit.h>

#define PREF_SERIAL_PORT @"SerialPort"
#define PREF_LIGHTS_STATE @"LightState"
#define PREF_LED_MODE @"LEDMode"

#define TEXT_CPU_USAGE @"CPU Usage"
#define TEXT_RAM_USAGE @"RAM Usage"
#define TEXT_GPU_USAGE @"GPU Usage"
#define TEXT_VRAM_USAGE @"VRAM Usage"
#define TEXT_CPU_TEMPERATURE @"CPU Temperature"
#define TEXT_GPU_TEMPERATURE @"GPU Temperature"

#define KEY_CPU_TEMPERATURE @"TC0D"
#define KEY_GPU_TEMPERATURE @"TG0D"

@interface AppDelegate ()

@property (weak) NSMenuItem *lastLEDMode;

@end

@implementation AppDelegate

@synthesize statusMenu, application;
@synthesize menuColors, menuAnimations, menuVisualizations, menuPorts;
@synthesize buttonOff, buttonLights;
@synthesize statusItem, statusImage;
@synthesize staticColors;
@synthesize serial, lastLEDMode;

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    serial = [[Serial alloc] init];
    lastLEDMode = nil;
    
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
    [store registerDefaults:appDefaults];
    [store synchronize];
    NSString *savedPort = [store stringForKey:PREF_SERIAL_PORT];
    BOOL turnOnLights = [store boolForKey:PREF_LIGHTS_STATE];
    NSString *lastMode = [store stringForKey:PREF_LED_MODE];
    
    // Prepare serial port menu
    NSArray *ports = [Serial listSerialPorts];
    if ([ports count] > 0) {
        [menuPorts removeAllItems];
        for (int i = 0; i < [ports count]; i++) {
            // Add Menu Item for this port
            NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:[ports objectAtIndex:i] action:@selector(selectedSerialPort:) keyEquivalent:@""];
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
        if ([key isEqualToString:lastMode]) {
            [self selectedVisualization:item];
        }
        [menuColors addItem:item];
    }
    
    // TODO Prepare animations menu
    
    JSKSystemMonitor *systemMonitor = [JSKSystemMonitor systemMonitor];
    
#ifdef DEBUG
    JSKMCPUUsageInfo cpuUsageInfo = systemMonitor.cpuUsageInfo;
    NSLog(@"CPU Usage: %.3f%%\n", cpuUsageInfo.usage);
    
    JSKMMemoryUsageInfo memoryUsageInfo = systemMonitor.memoryUsageInfo;
    NSLog(@"Memory Usage: %.2fGB Free + %.2fGB Used = %.2fGB\n", memoryUsageInfo.freeMemory / (1024.0 * 1024.0 * 1024.0), memoryUsageInfo.usedMemory / (1024.0 * 1024.0 * 1024.0), (memoryUsageInfo.freeMemory + memoryUsageInfo.usedMemory) / (1024.0 * 1024.0 * 1024.0));
#endif
    
    // Add CPU Usage menu item
    NSMenuItem *cpuUsageItem = [[NSMenuItem alloc] initWithTitle:TEXT_CPU_USAGE action:@selector(selectedVisualization:) keyEquivalent:@""];
    if ([lastMode isEqualToString:TEXT_CPU_USAGE]) {
        [self selectedVisualization:cpuUsageItem];
    }
    [menuVisualizations addItem:cpuUsageItem];
    
    // Add Memory Usage item
    NSMenuItem *memoryUsageItem = [[NSMenuItem alloc] initWithTitle:TEXT_RAM_USAGE action:@selector(selectedVisualization:) keyEquivalent:@""];
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
        if ([lastMode isEqualToString:TEXT_GPU_USAGE]) {
            [self selectedVisualization:itemUsage];
        }
        [menuVisualizations addItem:itemUsage];
        
        NSMenuItem *itemVRAM = [[NSMenuItem alloc] initWithTitle:TEXT_VRAM_USAGE action:@selector(selectedVisualization:) keyEquivalent:@""];
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
            if ([lastMode isEqualToString:TEXT_CPU_TEMPERATURE]) {
                [self selectedVisualization:item];
            }
            [menuVisualizations addItem:item];
        }
        
        if ([key isEqualToString:KEY_GPU_TEMPERATURE]) {
            NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:TEXT_GPU_TEMPERATURE action:@selector(selectedVisualization:) keyEquivalent:@""];
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
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
    // Close serial port, if it was opened
    if ([serial isOpen]) {
        [serial closePort];
    }
}
- (IBAction)relistSerialPorts:(id)sender {
    // Refill port list
    NSArray *ports = [Serial listSerialPorts];
    [menuPorts removeAllItems];
    for (int i = 0; i < [ports count]; i++) {
        // Add Menu Item for this port
        NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:[ports objectAtIndex:i] action:@selector(selectedSerialPort:) keyEquivalent:@""];
        [menuPorts addItem:item];
        
        // Mark it if it is currently open
        if ([serial isOpen]) {
            if ([[ports objectAtIndex:i] isEqualToString:[serial portName]]) {
                [[menuPorts itemAtIndex:i] setState:NSOnState];
            }
        }
    }
}

- (IBAction)turnLEDsOff:(NSMenuItem *)sender {
    if ([sender state] == NSOffState) {
        lastLEDMode = nil;

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
        if ([serial isOpen]) {
            [serial sendString:@"RGB 0 0 0\n"];
        }
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
    [buttonOff setState:NSOffState];
    [sender setState:NSOnState];
    
    if ([sender.title isEqualToString:TEXT_GPU_USAGE]) {
        // TODO send command
        
    } else if ([sender.title isEqualToString:TEXT_VRAM_USAGE]) {
        // TODO send command
        
    } else if ([sender.title isEqualToString:TEXT_GPU_TEMPERATURE]) {
        // TODO send command
        
    } else if ([sender.title isEqualToString:TEXT_CPU_USAGE]) {
        // TODO send command
        
    } else if ([sender.title isEqualToString:TEXT_CPU_TEMPERATURE]) {
        // TODO send command
        
    } else if ([sender.title isEqualToString:TEXT_RAM_USAGE]) {
        // TODO send command
        
    } else {
        BOOL found = NO;
        
        // Check if a static color was selected
        if (staticColors != nil) {
            for (NSString *key in [staticColors allKeys]) {
                if ([sender.title isEqualToString:key]) {
                    found = YES;
                    
                    NSColor *color = [staticColors valueForKey:key];
                    unsigned char red = [color redComponent] * 255;
                    unsigned char green = [color greenComponent] * 255;
                    unsigned char blue = [color blueComponent] * 255;
                    NSString *string = [NSString stringWithFormat:@"RGB %d %d %d\n", red, green, blue];
                    
                    if ([serial isOpen]) {
                        [serial sendString:string];
                    }
                }
            }
        }
        
        if (found) goto end_found;
        
        // TODO Check if an animation was selected
        
        NSLog(@"Unknown LED Visualization selected!\n");
        return;
    }

    end_found: {
        // Store changed value in preferences
        NSUserDefaults *store = [NSUserDefaults standardUserDefaults];
        [store setObject:[sender title] forKey:PREF_LED_MODE];
        [store synchronize];
        
#ifdef DEBUG
        NSLog(@"Stored new mode: \"%@\"!\n", [sender title]);
#endif
    }
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
        // TODO Restore the current configuration
    }
}

- (IBAction)showAbout:(id)sender {
    [NSApp activateIgnoringOtherApps:YES];
    [application orderFrontStandardAboutPanel:self];
}

@end
