//
//  POSTrackableAssert.h
//  POSHockeyAppExtension
//
//  Created by Pavel Osipov on 13/07/16.
//  Copyright © 2016 Pavel Osipov. All rights reserved.
//

#import <POSHockeyAppExtension/POSHockeyAppTracker.h>
#import <CrashReporter/CrashReporter.h>

/// Sends report with specified description to HockeyApp service if condition is false.
#define POS_TRACKABLE_ASSERT_EX(tracker, condition, description, ...) \
do { \
    NSAssert((condition), description, ##__VA_ARGS__); \
    if (!(condition)) { \
        NSData *report = [[BITPLCrashReporter sharedReporter] generateLiveReportAndReturnError:nil]; \
        if (report) { \
            [tracker fireAssertReport:report withPayload:description, ##__VA_ARGS__]; \
        } \
    } \
} while (0)

/// Sends report to HockeyApp service if condition is false.
#define POS_TRACKABLE_ASSERT(tracker, condition) \
        POS_TRACKABLE_ASSERT_EX(tracker, condition, ([NSString stringWithFormat:@"'%s' is false.", #condition]))
