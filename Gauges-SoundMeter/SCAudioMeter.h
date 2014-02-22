//
//  SCAudioMeter.h
//  Gauges-SoundMeter
//
//  Created by Sam Davies on 19/02/2014.
//  Copyright (c) 2014 Shinobi Controls. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface SCAudioMeter : NSObject

- (instancetype)initWithSamplePeriod:(NSTimeInterval)samplePeriod;
- (void)beginAudioMeteringWithCallback:(void (^)(double value))callback;
- (void)endAudioMetering;

@end
