//
//  GPUStats.m
//  CaseLights
//
//  For more informations refer to this StackOverflow answer:
//  http://stackoverflow.com/a/22440235
//
//  Created by Thomas Buck on 23.12.15.
//  Copyright © 2015 xythobuz. All rights reserved.
//

#import <IOKit/IOKitLib.h>

#import "GPUStats.h"

@implementation GPUStats

+ (NSInteger)getGPUUsage:(NSNumber **)usage freeVRAM:(NSNumber **)free usedVRAM:(NSNumber **)used {
    if ((usage == nil) || (free == nil) || (used == nil)) {
        NSLog(@"Invalid use of getGPUUsage!\n");
        return 1;
    }
    
    *usage = nil;
    *free = nil;
    *used = nil;
    
    CFMutableDictionaryRef pciDevices = IOServiceMatching(kIOAcceleratorClassName);
    io_iterator_t iterator;
    if (IOServiceGetMatchingServices(kIOMasterPortDefault, pciDevices, &iterator) == kIOReturnSuccess) {
        io_registry_entry_t registry;
        while ((registry = IOIteratorNext(iterator))) {
            CFMutableDictionaryRef services;
            if (IORegistryEntryCreateCFProperties(registry, &services, kCFAllocatorDefault, kNilOptions) == kIOReturnSuccess) {
                CFMutableDictionaryRef properties = (CFMutableDictionaryRef)CFDictionaryGetValue(services, CFSTR("PerformanceStatistics"));
                if (properties) {
                    const void *gpuUsage = CFDictionaryGetValue(properties, CFSTR("GPU Core Utilization"));
                    const void *freeVRAM = CFDictionaryGetValue(properties, CFSTR("vramFreeBytes"));
                    const void *usedVRAM = CFDictionaryGetValue(properties, CFSTR("vramUsedBytes"));
                    
                    if (gpuUsage && freeVRAM && usedVRAM) {
                        // Found the GPU. Store this reference for the next call
                        static ssize_t gpuUsageNum = 0;
                        static ssize_t freeVRAMNum = 0;
                        static ssize_t usedVRAMNum = 0;
                        CFNumberGetValue((CFNumberRef)gpuUsage, kCFNumberSInt64Type, &gpuUsageNum);
                        CFNumberGetValue((CFNumberRef)freeVRAM, kCFNumberSInt64Type, &freeVRAMNum);
                        CFNumberGetValue((CFNumberRef)usedVRAM, kCFNumberSInt64Type, &usedVRAMNum);
                        *usage = [NSNumber numberWithDouble:gpuUsageNum / 10000000.0];
                        *free = [NSNumber numberWithDouble:freeVRAMNum];
                        *used = [NSNumber numberWithDouble:usedVRAMNum];
                        
#ifdef DEBUG
                        NSLog(@"GPU: %.3f%% VRAM: %.3f%% (%.2fMB)\n", gpuUsageNum / 10000000.0, ((double)usedVRAMNum) / (freeVRAMNum + usedVRAMNum) * 100.0, (usedVRAMNum + freeVRAMNum) / (1024.0 * 1024.0));
#endif
                    }
                }
                CFRelease(services);
            }
            IOObjectRelease(registry);
        }
        IOObjectRelease(iterator);
    } else {
        NSLog(@"Couldn't list PCI devices!\n");
    }
    
    if ((*usage != nil) && (*free != nil) && (*used != nil)) {
        return 0;
    } else {
        NSLog(@"Error reading GPU data!\n");
        return 1;
    }
}

@end
