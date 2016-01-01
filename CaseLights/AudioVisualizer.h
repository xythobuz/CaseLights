//
//  AudioVisualizer.h
//  CaseLights
//
//  Created by Thomas Buck on 01.01.16.
//  Copyright © 2016 xythobuz. All rights reserved.
//

#import <Foundation/Foundation.h>

@class AppDelegate;

@interface AudioVisualizer : NSObject

+ (void)setDelegate:(AppDelegate *)delegate;
+ (void)updateBuffer:(float *)buffer withBufferSize:(UInt32)bufferSize;

@end
