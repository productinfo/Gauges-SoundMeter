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

Start out with a simple __Single View Application__ and create a __PodFile__
which contains the following:

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


## Configure the Gauge


## Conclusion

