//
//  SCViewController.m
//  Gauges-SoundMeter
//
//  Created by Sam Davies on 18/02/2014.
//  Copyright (c) 2014 Shinobi Controls. All rights reserved.
//

#import "SCViewController.h"
#import "SCAudioMeter.h"
#import <ShinobiGauges/ShinobiGauges.h>

@interface SCViewController ()

@property (nonatomic, strong) SCAudioMeter *audioMeter;
@property (nonatomic, strong) SGaugeRadial *gauge;

@end

@implementation SCViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    [ShinobiGauges setLicenseKey:@"<YOUR LICENSE KEY HERE>"];
    // Create a gauge
    [self createGauge];
    
    // Let's try the audio meter
    self.audioMeter = [[SCAudioMeter alloc] initWithSamplePeriod:0.1];
    [self.audioMeter beginAudioMeteringWithCallback:^(double value) {
        NSLog(@"RMS Value: %0.3f", 10 * log10(value));
        [self.gauge setValue:10 * log10(value) duration:0.1];
    }];
    
}

#pragma mark - Utility Methods
- (void)createGauge
{
    self.gauge = [[SGaugeRadial alloc] initWithFrame:CGRectInset(self.view.bounds, 40, 100)
                                         fromMinimum:@(-60)
                                           toMaximum:@0];
    
    // Set up some qualatitive ranges
    self.gauge.qualitativeRanges = @[
        [SGaugeQualitativeRange rangeWithMinimum:@-60
                                         maximum:@-15
                                           color:[[UIColor greenColor] colorWithAlphaComponent:0.4]],
        [SGaugeQualitativeRange rangeWithMinimum:@-15
                                         maximum:@-7.5
                                           color:[[UIColor yellowColor] colorWithAlphaComponent:0.4]],
        [SGaugeQualitativeRange rangeWithMinimum:@-7.5
                                         maximum:@-2.5
                                           color:[[UIColor orangeColor] colorWithAlphaComponent:0.4]],
        [SGaugeQualitativeRange rangeWithMinimum:@-2.5
                                         maximum:@0
                                           color:[[UIColor redColor] colorWithAlphaComponent:0.4]]
        ];
    self.gauge.style.qualitativeRangeOuterPosition = self.gauge.style.tickBaselinePosition;
    self.gauge.style.qualitativeRangeInnerPosition = 0.85;
    
    self.gauge.style.majorTickSize = CGSizeMake(2, 17);
    
    [self.view addSubview:self.gauge];
}

@end
