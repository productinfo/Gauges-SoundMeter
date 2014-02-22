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
        // Convert the value to a dB (logarithmic) scale
        double dBValue = 10 * log10(value);
        [self.gauge setValue:dBValue duration:0.1];
    }];
    
}

#pragma mark - Utility Methods
- (void)createGauge
{
    self.gauge = [[SGaugeRadial alloc] initWithFrame:CGRectInset(self.view.bounds, 40, 100)
                                         fromMinimum:@(-60)
                                           toMaximum:@0];
    
    SGaugeStyle *gs = self.gauge.style;
    
    // Set up some qualatitive ranges
    self.gauge.qualitativeRanges = @[
        [SGaugeQualitativeRange rangeWithMinimum:@-60
                                         maximum:@-15
                                           color:[[UIColor greenColor] colorWithAlphaComponent:0.4]],
        [SGaugeQualitativeRange rangeWithMinimum:@-15
                                         maximum:@-8
                                           color:[[UIColor yellowColor] colorWithAlphaComponent:0.4]],
        [SGaugeQualitativeRange rangeWithMinimum:@-8
                                         maximum:@-2
                                           color:[[UIColor orangeColor] colorWithAlphaComponent:0.4]],
        [SGaugeQualitativeRange rangeWithMinimum:@-2
                                         maximum:@0
                                           color:[[UIColor redColor] colorWithAlphaComponent:0.4]]
        ];
    gs.qualitativeRangeOuterPosition = gs.tickBaselinePosition;
    gs.qualitativeRangeInnerPosition = 0.85;
    
    gs.majorTickSize = CGSizeMake(2, 17);
    
    gs.knobRadius = 10;
    gs.knobColor = [UIColor darkGrayColor];
    gs.knobBorderWidth = 2;
    gs.needleWidth = 10;
    gs.needleBorderWidth = 2;
    gs.needleColor = [[UIColor orangeColor] colorWithAlphaComponent:0.8];
    gs.needleBorderColor = [[UIColor darkGrayColor] colorWithAlphaComponent:0.6];
    
    gs.tickLabelFont = [self.gauge.style.tickLabelFont fontWithSize:20];
    gs.tickLabelOffsetFromBaseline = -33;
    gs.tickLabelColor = [UIColor darkTextColor];
    
    gs.tickBaselineWidth = 2;
    gs.tickBaselineColor = [UIColor colorWithWhite:0.1 alpha:1];
    gs.majorTickColor = gs.tickBaselineColor;
    gs.minorTickColor = gs.tickBaselineColor;
    
    gs.innerBackgroundColor = [UIColor lightGrayColor];
    gs.outerBackgroundColor = [UIColor grayColor];
    
    gs.bevelPrimaryColor = [UIColor lightGrayColor];
    gs.bevelSecondaryColor = [UIColor whiteColor];
    
    [self.view addSubview:self.gauge];
}

@end
