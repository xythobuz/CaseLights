//
//  AppDelegate.h
//  CaseLights
//
//  Created by Thomas Buck on 21.12.15.
//  Copyright © 2015 xythobuz. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "EZAudio.h"
#import "SystemInfoKit/SystemInfoKit.h"

@class Serial;

@interface AppDelegate : NSObject <NSApplicationDelegate, EZMicrophoneDelegate>

- (void)clearDisplayUI;
- (void)updateDisplayUI:(NSArray *)displayIDs;

- (void)setLightsR:(unsigned char)r G:(unsigned char)g B:(unsigned char)b;

@end

