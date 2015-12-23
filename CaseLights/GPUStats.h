//
//  GPUStats.h
//  CaseLights
//
//  Created by Thomas Buck on 23.12.15.
//  Copyright © 2015 xythobuz. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface GPUStats : NSObject

+ (NSInteger)getGPUUsage:(NSNumber **)usage freeVRAM:(NSNumber **)free usedVRAM:(NSNumber **)used;

@end
