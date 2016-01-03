//
//  AudioVisualizer.m
//  CaseLights
//
//  Based on the ideas in:
//  http://archive.gamedev.net/archive/reference/programming/features/beatdetection/
//
//  The detected sound frequency of beats will be mapped to the hue of the resulting color,
//  the variance of the beat is mapped to the brightness of the color. The colors
//  of all detected beats will be added together to form the final displayed color.
//
//  Created by Thomas Buck on 01.01.16.
//  Copyright © 2016 xythobuz. All rights reserved.
//

// Enabling this will cause crashes when changing audio input
// devices while the app is running. Select it before enabling.
#define DEBUG_PLOT_FFT
//#define DEBUG_PLOT_FFT_RAW

#define DEBUG_LOG_BEATS

#import "AudioVisualizer.h"
#import "AppDelegate.h"

#import "EZAudioFFT.h"

#ifdef DEBUG_PLOT_FFT
#import "EZAudioPlot.h"
#endif

// Parameters for fine-tuning beat detection
#define FFT_BUCKET_COUNT 64
#define FFT_BUCKET_HISTORY 43
#define FFT_C_FACTOR 4.2
#define FFT_V0_FACTOR 0.000015
#define FFT_MAX_V0_COLOR 0.0002
#define FFT_COLOR_DECAY 0.99

// Factors for nicer debug display
#define FFT_DEBUG_RAW_FACTOR 42.0
#define FFT_DEBUG_FACTOR 230.0

static AppDelegate *appDelegate = nil;
static EZAudioFFT *fft = nil;
static int maxBufferSize = 0;

@implementation AudioVisualizer

+ (void)setDelegate:(AppDelegate *)delegate {
    appDelegate = delegate;
}

+ (void)updateBuffer:(float *)buffer withBufferSize:(UInt32)bufferSize {
    // Create Fast Fourier Transformation object
    if (fft == nil) {
        maxBufferSize = bufferSize;
        fft = [EZAudioFFT fftWithMaximumBufferSize:maxBufferSize sampleRate:appDelegate.microphone.audioStreamBasicDescription.mSampleRate];
        
#ifdef DEBUG
        NSLog(@"Created FFT with max. freq.: %.2f\n", appDelegate.microphone.audioStreamBasicDescription.mSampleRate / 2);
#endif
    }
    
    // Check for changing buffer sizes
    if (bufferSize > maxBufferSize) {
        NSLog(@"Buffer Size changed?! %d != %d\n", maxBufferSize, bufferSize);
        maxBufferSize = bufferSize;
        fft = [EZAudioFFT fftWithMaximumBufferSize:maxBufferSize sampleRate:appDelegate.microphone.audioStreamBasicDescription.mSampleRate];
    }
    
    [fft computeFFTWithBuffer:buffer withBufferSize:bufferSize];
    
    static float history[FFT_BUCKET_COUNT][FFT_BUCKET_HISTORY];
    static int nextHistory =  0;
    static int samplesPerBucket = 0;
    
    // Initialize static variables
    if (samplesPerBucket == 0) {
        samplesPerBucket = bufferSize / FFT_BUCKET_COUNT;
        for (int i = 0; i < FFT_BUCKET_COUNT; i++) {
            for (int j = 0; j < FFT_BUCKET_HISTORY; j++) {
                history[i][j] = 0.5f;
            }
        }
    }
    
    // Split FFT output into a small number of 'buckets' or 'bins' and add to circular history buffer
    for (int i = 0; i < FFT_BUCKET_COUNT; i++) {
        float sum = 0.0f;
        for (int j = 0; j < samplesPerBucket; j++) {
            sum += fft.fftData[(i + samplesPerBucket) + j];
        }
        history[i][nextHistory] = sum / samplesPerBucket;
    }
    
#ifdef DEBUG_PLOT_FFT
    int beatCount = 0;
#endif
    
    static unsigned char lastRed = 0, lastGreen = 0, lastBlue = 0;
    lastRed = lastRed * FFT_COLOR_DECAY;
    lastGreen = lastGreen * FFT_COLOR_DECAY;
    lastBlue = lastBlue * FFT_COLOR_DECAY;
    
    // Check for any beats
    for (int i = 0; i < FFT_BUCKET_COUNT; i++) {
        float average = 0.0f;
        for (int j = 0; j < FFT_BUCKET_HISTORY; j++) {
            average += history[i][j];
        }
        average /= FFT_BUCKET_HISTORY;
        float v = 0.0f;
        for (int j = 0; j < FFT_BUCKET_HISTORY; j++) {
            float tmp = history[i][j] - average;
            tmp *= tmp;
            v += tmp;
        }
        v /= FFT_BUCKET_HISTORY;
        if ((history[i][nextHistory] > (FFT_C_FACTOR * average)) && (v > FFT_V0_FACTOR)) {
            // Found a beat on this frequency band, map to a single color
            if (v < FFT_V0_FACTOR) v = FFT_V0_FACTOR;
            if (v > FFT_MAX_V0_COLOR) v = FFT_MAX_V0_COLOR;
            float bright = [AppDelegate map:v FromMin:FFT_V0_FACTOR FromMax:FFT_MAX_V0_COLOR ToMin:0.0 ToMax:100.0];
            float hue = [AppDelegate map:i FromMin:0.0 FromMax:FFT_BUCKET_COUNT ToMin:0.0 ToMax:360.0];
            unsigned char r, g, b;
            [AppDelegate convertH:hue S:1.0 V:bright toR:&r G:&g B:&b];
            
            // Blend with last color using averaging
            int tmpR = (lastRed + r) / 2;
            int tmpG = (lastGreen + g) / 2;
            int tmpB = (lastBlue + b) / 2;
            lastRed = tmpR;
            lastGreen = tmpG;
            lastBlue = tmpB;
            
#ifdef DEBUG_LOG_BEATS
            NSLog(@"Beat in %d with c: %f v: %f", i, (history[i][nextHistory] / average), v);
#endif
#ifdef DEBUG_PLOT_FFT
            beatCount++;
#endif
        }
    }
    
    [appDelegate setLightsR:lastRed G:lastGreen B:lastBlue];

#ifdef DEBUG_PLOT_FFT
    static NSWindow *window = nil;
    static EZAudioPlot *plot = nil;
    static NSTextField *label = nil;
    if ((window == nil) || (plot == nil) || (label == nil)) {
        NSRect frame = NSMakeRect(450, 300, 600, 400);
        window = [[NSWindow alloc] initWithContentRect:frame
                                             styleMask:NSClosableWindowMask | NSTitledWindowMask | NSBorderlessWindowMask
                                               backing:NSBackingStoreBuffered
                                                 defer:NO];
        [window setTitle:@"Debug FFT"];
        
        plot = [[EZAudioPlot alloc] initWithFrame:window.contentView.frame];
        plot.color = [NSColor whiteColor];
        plot.shouldOptimizeForRealtimePlot = NO; // Not working with 'YES' here?!
        plot.shouldFill = YES;
        plot.shouldCenterYAxis = NO;
        plot.shouldMirror = NO;
        plot.plotType = EZPlotTypeBuffer;
        [window.contentView addSubview:plot];
        
        label = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 380, 600, 20)];
        [label setTextColor:[NSColor whiteColor]];
        [label setEditable:NO];
        [label setBezeled:NO];
        [label setDrawsBackground:NO];
        [label setSelectable:NO];
        [label setStringValue:@"-"];
        [window.contentView addSubview:label];
        
        [window makeKeyAndOrderFront:appDelegate.application];
        NSLog(@"Created debugging FFT Plot window...\n");
    }
    
    // Scale so we can see something
# ifdef DEBUG_PLOT_FFT_RAW
    memcpy(buffer, fft.fftData, bufferSize * sizeof(float));
    for (UInt32 i = 0; i < bufferSize; i++) {
        buffer[i] *= FFT_DEBUG_RAW_FACTOR;
# else
    for (int i = 0; i < FFT_BUCKET_COUNT; i++) {
        buffer[i] = history[i][nextHistory];
    }
    for (UInt32 i = 0; i < FFT_BUCKET_COUNT; i++) {
        buffer[i] *= FFT_DEBUG_FACTOR;
# endif
        if (buffer[i] > 1.0f) buffer[i] = 1.0f;
        if (buffer[i] < -1.0f) buffer[i] = -1.0f;
    }
    [plot updateBuffer:buffer withBufferSize:bufferSize];
    
    [window setBackgroundColor:[NSColor colorWithCalibratedRed:lastRed / 255.0 green:lastGreen / 255.0 blue:lastBlue / 255.0 alpha:1.0]];
    [label setStringValue:[NSString stringWithFormat:@"Beats: %d", beatCount]];
#endif
        
    // Point to next history buffer
    nextHistory++;
    if (nextHistory >= FFT_BUCKET_HISTORY) {
        nextHistory = 0;
    }
}

@end
