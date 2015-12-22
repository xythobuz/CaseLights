//
//  Thread.h
//  SerialGamepad
//
//  Created by Thomas Buck on 15.12.15.
//  Copyright © 2015 xythobuz. All rights reserved.
//

#import <Foundation/Foundation.h>

@class AppDelegate;

@interface Thread : NSThread

@property BOOL running;
@property int fd;
@property (strong) NSString *portName;
@property (weak) AppDelegate *appDelegate;

- (id)initWithDelegate:(AppDelegate *)delegate;
- (NSInteger)openPort;

@end
