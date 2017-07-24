ShinobiGauges SoundMeter (Objective-C)
=====================

Ever since the iPhone first came out, the audio meter category of apps has
been very popular. In this blog post you'll learn how to create your own
version, using a ShinobiGauge to display the result.

![Screenshot](screenshot.png?raw=true)

Building the project
------------------

In order to build this project you'll need a copy of ShinobiGauges. If you don't have it yet, you can download a free trial from the [ShinobiGauges website](http://www.shinobicontrols.com/ios/shinobigauges).

If you've used the installer to install ShinobiGauges, the project should just work. If you haven't, then once you've downloaded and unzipped ShinobiGauges, open up the project in Xcode, and drag ShinobiGauges.framework from the finder into Xcode's 'frameworks' group, and Xcode will sort out all the header and linker paths for you.

If you’re using the trial version you’ll need to add your trial key. To do so, open up AppDelegate.m, import <ShinobiGauges/ShinobiGauges.h>, and set the trial key inside application:didFinishLaunchingWithOptions: as follows:

    #import <ShinobiGauges/ShinobiGauges.h>

    @implementation AppDelegate

    - (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
    {
        [ShinobiGauges setTrialKey:@"your trial key"];
        …
    }

The project uses [CocoaPods](http://cocoapods.org/), so you'll need to have CocoaPods set up, and to run `pod install` before you will be able to get the project to compile. There is further info in the [project writeup](ShinobiGauges-SoundMeter.md).

Contributing
------------

We'd love to see your contributions to this project - please go ahead and fork it and send us a pull request when you're done! Or if you have a new project you think we should include here, email info@shinobicontrols.com to tell us about it.

License
-------

The [Apache License, Version 2.0](LICENSE) applies to everything in this repository, and will apply to any user contributions.
