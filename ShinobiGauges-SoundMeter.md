# Building an Audio Meter using ShinobiGauges


## Introduction

Ever since the iPhone first came out, the audio meter category of apps has been
very popular. In this blog post you'll learn how to create your own version,
using a ShinobiGauge to display the result.

First of all we'll take a look at how to actually calculate the level from the
microphone, before adding a gauge to display the result.

As ever, all the source code for this project is available on Github at
[github.com/ShinobiControls/ShinobiGauges-SoundMeter](https://github.com/sammyd/ShinobiGauges-SoundMeter).
Feel free to fork it and have a play - I'd love a pull request with any issues
you come across :)


## Audio Metering

At its simplest, digital audio is just a one-dimensional sequence of numbers,
and since this represents a wave, determining the amplitude is as simple as
calculating the root mean squared (RMS) value. You'll see how simple this is
later on, but first you need to get access to this sequence of numbers from the
microphone on your iOS device.

There are a couple of routes into audio for iOS - __AVFoundation__ is a
high-level framework used for the recording and playback of media, and
__CoreAudio__ (via __AudioQueues__ and __AudioUnits__) is a lower-level
framework upon which __AVFoundation__ sits. The __CoreAudio__ route gives you
access to realtime samples from the microphone, but it has a C-API, and can be
a bit of a pain to get your head around.

Luckily, this is a recognized sticking point, and there are lots of open-source
frameworks available to ease the process of working with media. We're going to
use one such framework - in the shape of
[EZAudio](https://github.com/syedhali/EZAudio), which is a really simple
framework for working with audio in iOS. It includes lots of functionality, of
which you'll only use a tiny piece today. If you need to work with audio then I
encourage you to check it out.

In order to use __EZAudio__, you need to have [CocoaPods](http://cocoapods.org/)
set up on your machine. If you haven't heard of __CocoaPods__ then you've been
missing out - it's a dependency management tool for objective-C projects -
modeled on [RubyGems](http://rubygems.org) in the ruby world. If you haven't
used it before then head over to the excellent guides at
[guides.cocoapods.org](http://guides.cocoapods.org/), to find out how.

Start out with a simple __Single View Application__ and create an empty file
called __PodFile__ which contains the following:

    pod 'EZAudio', '~> 0.0.3'

Then, to get __CocoaPods__ to download and configure __EZAudio__, run the
following:

    pod install

Once that has completed, you can reopen the project, this time (and from now on)
opening the __.xcworkspace__ instead of the __.xcodeproj__.

Note that if you have downloaded the completed project from Github, you'll also
need to have __CocoaPods__ set up correctly, and to run `pod install` before
you will be able to get the project to compile. This is standard __CocoaPods__
procedure, and ensures that repos don't becoming huge due to duplicated
dependency code.


### Creating a metering class

We'll put all the code associated with measuring the sound level in one class,
so create a new class called `SCAudioMeter` and add the following methods to
the API:

    @interface SCAudioMeter : NSObject

    - (instancetype)initWithSamplePeriod:(NSTimeInterval)samplePeriod;
    - (void)beginAudioMeteringWithCallback:(void (^)(double value))callback;
    - (void)endAudioMetering;

    @end

The part of __EZAudio__ that you're going to use is `EZMicrophone`, which is a
class with a simple API. It has methods to `startFetchingAudio`,
`stopFetchingAudio` and whilst fetching is in progress, it will call a method
on its delegate - you'll see all of these being used later on.

You'll notice that the start metering method (`beginAudioMeteringWithCallback:`)
takes a block, which will be called when a new sample is ready. Now, one option
is to call this every time that a buffer of samples has been provided to the
microphone delegate method, but with experimentation I found that this was too
often, and caused quite jittery results. Therefore we instead resample the
audio over a longer period. In signal processing, there is a trade-off between
the smoothing provided by the longer sample period, and the lack of temporal
accuracy. The `initWithSamplePeriod:` method takes an `NSTimeInterval` value
which specifies how often the RMS value should be passed to the callback. To do
this we use an `NSTimer`, along with some accumulator properties:

    #import <EZAudio/EZMicrophone.h>

    @interface SCAudioMeter () <EZMicrophoneDelegate>

    @property (nonatomic, copy) void (^measurementCallback)(double value);
    @property (nonatomic, strong) EZMicrophone *microphone;

    @property (nonatomic, weak) NSTimer *timer;
    @property (nonatomic, assign) NSTimeInterval period;

    @property (nonatomic, assign) double runningSumSquares;
    @property (nonatomic, assign) NSUInteger numberSamples;

    @property (nonatomic, strong) dispatch_queue_t sampleProcessingQueue;

    @end

The `sampleProcessingQueue` is used to deal with threading issues - whenever
new samples arrive from the microphone, or the timer fires, all the
calculations occur on the queue to ensure that only one operation occurs at
once. It's created in the constructor:

    - (instancetype)initWithSamplePeriod:(NSTimeInterval)samplePeriod
    {
        self = [super init];
        if (self) {
            self.microphone = [EZMicrophone microphoneWithDelegate:self];
            self.period = samplePeriod;
            self.sampleProcessingQueue = dispatch_queue_create("com.shinobicontrols.gauges.soundmeter.processqueue", NULL);
        }
        return self;
    }

When a user requests that metering starts the following method gets called:

    - (void)beginAudioMeteringWithCallback:(void (^)(double))callback
    {
        self.measurementCallback = callback;
        
        // Start with sensible values
        self.runningSumSquares = 0;
        self.numberSamples = 0;
        
        [self.microphone startFetchingAudio];
        self.timer = [NSTimer scheduledTimerWithTimeInterval:self.period
                                                      target:self
                                                    selector:@selector(handleTimerFired)
                                                    userInfo:nil
                                                     repeats:YES];
    }

This resets the accumulator properties, starts the `EZMicrophone` audio fetch,
and creates a timer which will repeatedly fire at the period provided at the
construction time. This is the method which will collate the results and return
them to the `measurementCallback` provided here, in the metering start method
(which we've saved off in a property).

Each time the timer fires, the following method will be called:

    - (void)handleTimerFired
    {
        // Need the sample processing to happen on the queue
        dispatch_async(self.sampleProcessingQueue, ^{
            // Calculate this period's value and push it back on the main thread
            double mean = self.runningSumSquares / self.numberSamples;
            double rms  = sqrt(mean);
            dispatch_async(dispatch_get_main_queue(), ^{
                // Return the value
                self.measurementCallback(rms);
            });
            // Reset for the next period
            self.runningSumSquares = 0;
            self.numberSamples = 0; 
        });
    }

Firstly we use `dispatch_async` to ensure to prevent writing new data to
`runningSumSquares` or `numberSamples` whilst the current RMS return value is
being calculated. The RMS value is the square root of the mean of the sum of
squares (hence the name). We calculate this and then (back on the main thread)
we return the rms value to the `measurementCallback()` block.

The accumulator variables are then reset to begin preparing the next sample
period.

Whenever the `EZMicrophone` has new samples it provides them by calling a
delegate method. We'll implement that method as follows:

    #pragma mark - EZMicrophoneDelegate methods
    - (void)microphone:(EZMicrophone *)microphone
      hasAudioReceived:(float **)buffer
        withBufferSize:(UInt32)bufferSize
    withNumberOfChannels:(UInt32)numberOfChannels
    {
        // We'll just use the first channel
        float *dataPoints = buffer[0];
        // Calculate sum of squares
        double sumSquares = 0;
        float *currentDP = dataPoints;
        for (UInt32 i=0; i<bufferSize; i++) {
            sumSquares += *currentDP * *currentDP;
            currentDP++;
        }
        
        // Add it to the running total
        dispatch_async(self.sampleProcessingQueue, ^{
            self.runningSumSquares += sumSquares;
            self.numberSamples += bufferSize;
        });
    }

The samples are provided as a two-dimensional array of floats - of size number
of channels by number of samples. For this usage, we'll just use the first
channel - referenced by `buffer[0]` and of length `bufferSize`. To calculate
the sum of squares for this buffer, a simple `for` loop is employed. Then, the
accumulator properties are updated, as a task on the processing queue to
prevent threading issues.

The final method which is part of this class is the one which stops the
metering:

    - (void)endAudioMetering
    {
        [self.timer invalidate];
        self.timer = nil;
        [self.microphone stopFetchingAudio];
    }

Here the timer is canceled, and the microphone is told to stop fetching data.

In order to check that this class is working correctly, we'll create one in the
view controller and log the output.

Import the header and create a property to keep hold of the meter:

    #import "SCAudioMeter.h"

    @interface SCViewController ()

    @property (nonatomic, strong) SCAudioMeter *audioMeter;

    @end

In `viewDidLoad` create the audio meter, and start the metering:

    // Let's try the audio meter
    self.audioMeter = [[SCAudioMeter alloc] initWithSamplePeriod:0.1];
    [self.audioMeter beginAudioMeteringWithCallback:^(double value) {
        NSLog(@"Value: %0.2f", value);
    }];

When you first start the app, you'll be asked whether you want to give
permission to use the microphone, and once you've agreed, then you'll start to
see some output in the log.

SCREEN_SHOT_OF_REQUEST

    2014-02-22 16:54:56.414 Gauges-SoundMeter[74741:70b] Value: 0.83
    2014-02-22 16:54:56.713 Gauges-SoundMeter[74741:70b] Value: 0.77
    2014-02-22 16:54:56.814 Gauges-SoundMeter[74741:70b] Value: 0.78
    2014-02-22 16:54:57.114 Gauges-SoundMeter[74741:70b] Value: 0.65
    2014-02-22 16:54:57.215 Gauges-SoundMeter[74741:70b] Value: 0.63
    2014-02-22 16:54:57.314 Gauges-SoundMeter[74741:70b] Value: 0.60
    2014-02-22 16:54:57.615 Gauges-SoundMeter[74741:70b] Value: 0.55

## Display the results

ShinobiGauges offer a really simple way to visualize one-dimensional data such
as this - and it works particularly well for temporal data. You can download a
fully-functional trial of ShinobiGauges from the website at
[shinobicontrols.com/ios/shinobigauges](http://www.shinobicontrols.com/ios/shinobigauges).
You can either run through the installer, which will provide the framework in
the developer frameworks section of the "link against libraries" dialog, or you
can drag the framework into the project. Details are provided in the getting
started guide, available on [ShinobiDeveloper](http://www.shinobicontrols.com/docs/ShinobiControls/ShinobiGauges/2.5.0/Standard/Normal/docs/documentation/GaugesUserGuide.html).

To use a ShinobiGauge, import the header at the top of the view controller and
add a property to reference the gauge:

    #import <ShinobiGauges/ShinobiGauges.h>

    @interface SCViewController ()

    @property (nonatomic, strong) SCAudioMeter *audioMeter;
    @property (nonatomic, strong) SGaugeRadial *gauge;

    @end

If you're using the trial version of gauges, then you need to set the license
key. In `viewDidLoad` add the following line, replacing with the key provided
in the email you received from ShinobiHQ:

    [ShinobiGauges setLicenseKey:@"<INSERT YOUR LICENSE KEY HERE>"];

The remainder of `viewDidLoad` looks like the following:

    // Create a gauge
    [self createGauge];
    
    // Let's try the audio meter
    self.audioMeter = [[SCAudioMeter alloc] initWithSamplePeriod:0.1];
    [self.audioMeter beginAudioMeteringWithCallback:^(double value) {
        [self.gauge setValue:value duration:0.1];
    }];

Instead of logging the `value` in the audio metering callback block, here we
set it as the value of the gauge. Using the `setValue:duration:` method will
cause the gauge to animate to the next value, which will smooth the motion of
the needle.

Creation of the gauge is handed off to a helper method, `createGauge`:

    - (void)createGauge
    {
        self.gauge = [[SGaugeRadial alloc] initWithFrame:CGRectInset(self.view.bounds, 40, 100)
                                             fromMinimum:@0
                                               toMaximum:@1];
        [self.view addSubview:self.gauge];
    }

If you run the app up now, and make some noise, then you'll see the needle
moving in response to the volume - pretty cool!

![Linear Gauge](img/gauge_linear.png)


## Rescaling the values

You set the range of the gauge to be 0 to 1, since this represents the possible
range of the RMS values generated by the sound meter class. However, because of
the way in which audio works, a logarithmic scale is more appropriate.
Typically, the decibel (dB) scale is used. It's important here to realize that
dBs themselves actually represent a ratio of value and maximum possible value,
and hence aren't necessarily comparable. The dB often used in relation to audio
volume refers to [sound pressure level](http://en.wikipedia.org/wiki/Decibel#Acoustics),
and requires calibration.

Change the scale of the gauge to be [-60, 0]:

    self.gauge = [[SGaugeRadial alloc] initWithFrame:CGRectInset(self.view.bounds, 40, 100)
                                             fromMinimum:@(-60)
                                               toMaximum:@0];

And update the sound meter callback block to convert the value to dB:

    [self.audioMeter beginAudioMeteringWithCallback:^(double value) {
        // Convert the value to a dB (logarithmic) scale
        double dBValue = 10 * log10(value);
        [self.gauge setValue:dBValue duration:0.1];
    }];

Now, if you run up the app, you'll again see a gauge which has a needle which
moves with the volume of detected sound, but this time it will be a lot more
sensitive to the quieter sounds, due to the logarithmic scaling.

![Log-Scaled Gauge](img/gauge_log.png)

## Configure the Gauge

The appearance of a ShinobiGauge is extremely configurable, primarily via the
style property - an `SGaugeStyle` object. First of all, we'll look at changing
the basic appearance, before adding a qualitative range to the gauge.

### Basic Appearance

There are a lot of properties on the `SGaugeStyle` object which control the
appearance of the gauge - as detailed in the [documentation](http://www.shinobicontrols.com/docs/ShinobiControls/ShinobiGauges/2.5.0/Standard/Normal/Classes/SGaugeStyle.html).
We'll take a look at some of them in the `createGauge` method:

    SGaugeStyle *gs = self.gauge.style;
    gs.knobRadius = 10;
    gs.knobColor = [UIColor darkGrayColor];
    gs.knobBorderWidth = 2;

Here we're configuring the appearance of the knob at the center of the gauge -
setting the size, color and border width. We can combine this with some config
of the needle itself:

    gs.needleWidth = 10;
    gs.needleBorderWidth = 2;
    gs.needleColor = [[UIColor orangeColor] colorWithAlphaComponent:0.8];
    gs.needleBorderColor = [[UIColor darkGrayColor] colorWithAlphaComponent:0.6];

The tick labels have similar properties to `UILabel` objects, which are
accessible on the style object:

    gs.tickLabelFont = [self.gauge.style.tickLabelFont fontWithSize:20];
    gs.tickLabelOffsetFromBaseline = -33;
    gs.tickLabelColor = [UIColor darkTextColor];

The __baseline__ is the circular axis towards the outside of the gauge. The
tick marks extend from the baseline, and both have some properties on the style
object:

    gs.tickBaselineWidth = 2;
    gs.tickBaselineColor = [UIColor colorWithWhite:0.1 alpha:1];
    gs.majorTickColor = gs.tickBaselineColor;
    gs.minorTickColor = gs.tickBaselineColor;

Finally, we can set the colors on the background and bevel of the gauge:

    gs.innerBackgroundColor = [UIColor lightGrayColor];
    gs.outerBackgroundColor = [UIColor grayColor];
    gs.bevelPrimaryColor = [UIColor lightGrayColor];
    gs.bevelSecondaryColor = [UIColor whiteColor];

If you run the app up now, you'll see the effect of the style changes you've
just made.

![Restyled Gauge](img/gauge_restyled.png)


### Qualitative Range

A qualitative range is represented by coloring a range on the gauge - for
example you might want really loud sounds to hit the red zone etc. These ranges
are specified on the gauge itself, as an array of `SGaugeQualitativeRange`
objects, each of which requires a color, and a start and end value:

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

In order to change the width of the range coloring, there are a couple of
properties on the style object:

    gs.qualitativeRangeOuterPosition = gs.tickBaselinePosition;
    gs.qualitativeRangeInnerPosition = 0.85;

Now, when you run the app up, you'll see the ranges colored as per the ranges
you specified above.


![Gauge with qualitative range](img/gauge_restyled_qualitative.png)


## Conclusion

In this post you've learnt how to use a ShinobiGauge for a very popular
app-type - an audio level meter. In actual fact, the most complicated part of
the app is actually obtaining the values to display using the gauge. The gauges
themselves are very configurable, and super-easy to style.

In this tutorial we only looked at using a radial gauge, but you could replace
it with a linear gauge instead - some of the styling code would change, but
everything else that you've written could remain the same.

The code for this is available on Github at [github.com/ShinobiControls/ShinobiGauges-SoundMeter](https://github.com/sammyd/ShinobiGauges-SoundMeter)
so you can download or clone it and try it out. Don't forget that you will need
to use CocoaPods to obtain the __EZAudio__ dependency, and to run `pod install`
to configure the projects correctly.

If you have any questions or comments feel free to leave a message below, or
grab me on twitter - [@iwantmyrealname](https://twitter.com/iwantmyrealname).

sam
