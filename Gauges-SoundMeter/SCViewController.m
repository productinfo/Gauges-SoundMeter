/*
 Copyright 2014 Scott Logic Ltd.
 
 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at
 
 http://www.apache.org/licenses/LICENSE-2.0
 
 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
 */

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
