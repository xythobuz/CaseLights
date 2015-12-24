//
//  Serial.h
//  SerialGamepad
//
//  Created by Thomas Buck on 14.12.15.
//  Copyright © 2015 xythobuz. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface Serial : NSObject

@property int fd;
@property (strong) NSString *portName;

- (NSInteger)openPort;
- (NSInteger)hasData;

+ (NSArray *)listSerialPorts;

@end
