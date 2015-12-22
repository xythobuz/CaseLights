//
//  Thread.m
//  SerialGamepad
//
//  Created by Thomas Buck on 15.12.15.
//  Copyright © 2015 xythobuz. All rights reserved.
//

#import <termios.h>
#import <fcntl.h>
#import <unistd.h>
#include <poll.h>

#import "Thread.h"
#import "AppDelegate.h"

@implementation Thread

@synthesize running, fd, portName, appDelegate;

- (id)initWithDelegate:(AppDelegate *)delegate {
    self = [super init];
    if (self != nil) {
        appDelegate = delegate;
    }
    return self;
}

- (NSInteger)openPort {
    if (portName == nil) {
        return 1;
    }
    
    // Open port read-only, without controlling terminal, non-blocking
    fd = open([portName UTF8String], O_RDONLY | O_NOCTTY | O_NONBLOCK);
    if (fd == -1) {
        NSLog(@"Error opening serial port \"%@\"!\n", portName);
        return 1;
    }
    
    fcntl(fd, F_SETFL, 0); // Enable blocking I/O
    
    // Read current settings
    struct termios options;
    tcgetattr(fd, &options);
    
    options.c_lflag = 0;
    options.c_oflag = 0;
    options.c_iflag = 0;
    options.c_cflag = 0;
    
    options.c_cflag |= CS8; // 8 data bits
    options.c_cflag |= CREAD; // Enable receiver
    options.c_cflag |= CLOCAL; // Ignore modem status lines
    
    cfsetispeed(&options, B115200);
    cfsetospeed(&options, B115200);
    
    options.c_cc[VMIN] = 0; // Return even with zero bytes...
    options.c_cc[VTIME] = 1; // ...but only after .1 seconds
    
    // Set new settings
    tcsetattr(fd, TCSANOW, &options);
    tcflush(fd, TCIOFLUSH);
    
    return 0;
}

- (NSInteger)hasData {
    struct pollfd fds;
    fds.fd = fd;
    fds.events = (POLLIN | POLLPRI); // Data may be read
    if (poll(&fds, 1, 0) > 0) {
        return 1;
    } else {
        return 0;
    }
}

- (void)main {
    NSLog(@"Connection running...\n");
    
    running = YES;
    while (running) {
        
    }
    
    close(fd);
    NSLog(@"Connection closed...\n");
    fd = -1;
}

@end
