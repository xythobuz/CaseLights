//
//  AudioVisualizer.m
//  CaseLights
//
//  Created by Thomas Buck on 01.01.16.
//  Copyright © 2016 xythobuz. All rights reserved.
//

#import "AudioVisualizer.h"
#import "AppDelegate.h"

static AppDelegate *appDelegate = nil;

@implementation AudioVisualizer

+ (void)setDelegate:(AppDelegate *)delegate {
    appDelegate = delegate;
}

+ (void)updateBuffer:(float *)buffer withBufferSize:(UInt32)bufferSize {
    
}

@end
