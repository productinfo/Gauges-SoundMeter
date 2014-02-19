//
//  SCAudioMeter.m
//  Gauges-SoundMeter
//
//  Created by Sam Davies on 19/02/2014.
//  Copyright (c) 2014 Shinobi Controls. All rights reserved.
//

#import "SCAudioMeter.h"
#import <EZAudio/EZMicrophone.h>

@interface SCAudioMeter () <EZMicrophoneDelegate>

@property (nonatomic, copy) void (^measurementCallback)(double value);
@property (nonatomic, strong) EZMicrophone *microphone;

@end


@implementation SCAudioMeter

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.microphone = [EZMicrophone microphoneWithDelegate:self];
    }
    return self;
}

- (void)beginAudioMeteringWithCallback:(void (^)(double))callback
{
    self.measurementCallback = callback;
    [self.microphone startFetchingAudio];
}

- (void)endAudioMetering
{
    [self.microphone stopFetchingAudio];
}

#pragma mark - EZMicrophoneDelegate methods
- (void)microphone:(EZMicrophone *)microphone
  hasAudioReceived:(float **)buffer
    withBufferSize:(UInt32)bufferSize
withNumberOfChannels:(UInt32)numberOfChannels
{
    // We'll just use the first channel
    float *dataPoints = buffer[0];
    // Calculate RMS
    double rms = 0;
    float *currentDP = dataPoints;
    for (UInt32 i=0; i<bufferSize; i++) {
        rms += *currentDP * *currentDP;
        currentDP++;
    }
    rms = sqrt(rms);
    
    // Marshal back to the main thread
    dispatch_async(dispatch_get_main_queue(), ^{
        // Return the value
        self.measurementCallback(rms);
    });
}

@end
