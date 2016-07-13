POSHockeyAppExtension
=====================

POSHockeyAppExtension is a plugin to HockeyApp SDK which makes it possible to send
regular application events to HockeyApp service. Those events have the same format
as crash logs sent by HockeyApp SDK. That means that they will be good citizens in
HockeyApp dashboard and may be treated as regular crash logs using all available
tools such as grouping, sorting, searching and a lot of statistics.

Custom events sent by POSHockeyAppExtension provide you with an ability to track
down and analyse possible problems in your code. HockeyApp SDK only sends crash
reports caused by abnormal program termination. At the same time there can be a
lot of other issues, even more serious than application crash. What about buggy
logouts or broken In-App purchases? In order to debug them you can send alarms
with custom descriptions and analyse problems using call stacks, application logs,
and event-specific payload.

Look, how simple it is:

```objective-c
POS_TRACKABLE_ASSERT_EX(_tracker, !url, @"Invalid URL: %@", url);
```

That one-liner triggers NSAssert in debug build or sends alarm in release build
with URL description inside. Here is how description tab of generated crash report
looks like.

![payload](https://raw.github.com/pavelosipov/POSHockeyAppExtension/master/.screenshots/payload.png)

## Installation

Add this to your Podspec:

```ruby
pod POSHockeyAppExtension, :git => 'https://github.com/pavelosipov/POSHockeyAppExtension.git'
```

Then run `pod install`. Temporary pod points to repository directly because of
[publishing issue](https://github.com/CocoaPods/CocoaPods/issues/5619).

POSHockeyAppExtension pod should replace HockeyApp pod in Podfile, because it
depends on HockeyApp-Sources pod. Another reason is the usage of the HockeyApp
SDK private API for sending crash reports. That is why POSHockeyAppExtension may
be locked to some specific version of HockeyApp SDK until migration to a new
version.

HockeyApp public API contains REST method for [sending custom crash logs](https://support.hockeyapp.net/kb/api/api-crashes)
and it is not a problem to implement that functionality inside POSHockeyAppExtension.
There are several reasons why POSHockeyAppExtension uses HockeyApp SDK private
API instead:

* Avoid dependencies on third party networking libraries.
* Compatibility with old iOS versions. Legacy iOS versions use NSURLConnection
for networking, but it is deprecated in later versions in favor of NSURLSession.
Supporting the wide range of iOS versions requires either using both networking
frameworks with a lot of boilerplate code or to relying on some third-party
networking library.

## Configuration

POSHockeyAppExtension consists of one class – `POSHockeyAppTracker`. Instance of
that class should be initialized just after the code which configures HockeyApp
SDK:

```objective-c
self.tracker = [[POSHockeyAppTracker alloc] 
                initWithCrashManager:BITHockeyManager.sharedHockeyManager.crashManager];
```

`POSHockeyAppTracker` has optional `backupDirectoryPath` property. It specifies
the folder where `POSHockeyAppTracker` stores crash logs if it is not possible to
send them immediately (for example, the app works in offline mode). Use
`sendPendingCrashReports` method to send all crash logs from that folder. Here is
a fully-featured way to initialize `POSHockeyAppTracker`:

```objective-c
self.tracker = [[POSHockeyAppTracker alloc]
                initWithCrashManager:BITHockeyManager.sharedHockeyManager.crashManager];

// Of course it will be much cleaner to make subdirectory in NSLibraryDirectory directory.
_tracker.backupDirectoryPath = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory,
                                                                   NSUserDomainMask,
                                                                   YES).first;

// // Sending crash logs from previous session.
[_tracker sendPendingCrashReports]; 
```

## Usage

There are two ways to use `POSHockeyAppTracker`. The major difference between them
is how HockeyApp organizes received alarms on the dashboard. On the screenshot
below you can look at how 2 similar packs of 10 alarms are organized. The first
pack of 10 crashes was moved into a signle crash group. Crashes from the second
pack have their own crash groups.

![payload](https://raw.github.com/pavelosipov/POSHockeyAppExtension/master/.screenshots/crash_groups.png)

### Single crash group

Different alarms in a single crash group may be distinguished by different app traces.

![payload](https://raw.github.com/pavelosipov/POSHockeyAppExtension/master/.screenshots/app_traces.png)

This method provides a clear separation between real crashes and pseudo-crashes.
The downside of this approach is that it is very easy to overlook new alarms
because new app traces don’t directly appear on the HockeyApp dashboard main page.

To send alarm that way you should use some method of `POSHockeyAppTracker` from
`sendLiveCrashReport` family.

```objective-c
[tracker sendLiveCrashReportWithPayload:
 [NSString stringWithFormat:@"Invalid URL: %@", URL] error:nil];
```

Those methods generate crash inside so they will be on top of generated call
stack and this is a reason why all crashes will be grouped in the same crash group.

### Separate crash groups

This approach makes it very easy and intuitive to sort out real crashes and custom
alarms in accordance with their emergency. New alarms will appear in the dashboard
immediately because new crash groups will be created.

To send alarm that way you should use some method of `POSHockeyAppTracker` from
`sendCrashReport` family. Crash report should be generated on the client side to
put target function on top of the call stack. POSHockeyAppExtension has a macros
that makes that job for you.

```objective-c
// Short version
POS_TRACKABLE_ASSERT(tracker, array.count == 0);

// Detailed version
POS_TRACKABLE_ASSERT_EX(tracker, array.count == 0, @"Array is not empty: %@", array);
```

## Summary

POSHockeyAppExtension helps a lot to debug cases which are very difficult to
reproduce using developer environment. It is helpful as it may not be an option
to ask user to send you application logs when something strange happened. That
library unlocks an easy way to detect those cases and to send alarms with any
data you need to debug them.
