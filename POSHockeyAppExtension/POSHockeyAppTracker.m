//
//  POSHockeyAppTracker.m
//  POSHockeyAppExtension
//
//  Created by Pavel Osipov on 04.07.16.
//  Copyright © 2016 Pavel Osipov. All rights reserved.
//

#import "POSHockeyAppTracker.h"

#if __has_include(<HockeySDK_Source/HockeySDK.h>)
# import <HockeySDK_Source/HockeySDK.h>
#else
# import <HockeySDK-Source/HockeySDK.h>
#endif

#if __has_include(<HockeySDK_Source/BITHockeyHelper.h>)
# import <HockeySDK_Source/BITHockeyHelper.h>
#else
# import <HockeySDK-Source/BITHockeyHelper.h>
#endif

#if __has_include(<HockeySDK_Source/BITCrashReportTextFormatter.h>)
# import <HockeySDK_Source/BITCrashReportTextFormatter.h>
#else
# import <HockeySDK-Source/BITCrashReportTextFormatter.h>
#endif

#include <sys/types.h>
#include <sys/sysctl.h>

NS_ASSUME_NONNULL_BEGIN

/// Public Morozov pattern for exposing some private API
/// from <HockeySDK-Source/BITCrashManagerPrivate.h>
@interface BITCrashManager (Paparazzi)

@property (nonatomic, weak) id delegate;

- (NSString *)encodedAppIdentifier;

- (NSString *)userIDForCrashReport;
- (NSString *)userNameForCrashReport;
- (NSString *)userEmailForCrashReport;

- (void)sendCrashReportWithFilename:(nullable NSString *)filename
                                xml:(NSString*)xml
                         attachment:(nullable BITHockeyAttachment *)attachment;

@end


@interface POSHockeyAppTracker ()
@property (nonatomic, readonly) BITCrashManager *crashManager;
@end

@implementation POSHockeyAppTracker {
    NSString * __nullable _backupDirectoryPath;
}
@synthesize backupDirectoryPath = _backupDirectoryPath;

#pragma mark Lifecycle

- (instancetype)initWithCrashManager:(BITCrashManager *)crashManager {
    NSParameterAssert(crashManager.serverURL);
    if (self = [super init]) {
        _crashManager = crashManager;
    }
    return self;
}

#pragma mark POSHockeyAppRequestBuilder

- (void)sendPendingCrashReports {
    if (!_backupDirectoryPath) {
        return;
    }
    NSDirectoryEnumerator *directoryEnumerator = [NSFileManager.defaultManager enumeratorAtPath:_backupDirectoryPath];
    [directoryEnumerator skipDescendents];
    NSString *crashLogFilename;
    while (crashLogFilename = [directoryEnumerator nextObject]) {
        NSString *crashLogPath = [_backupDirectoryPath stringByAppendingPathComponent:crashLogFilename];
        NSString *crashLog = [NSString stringWithContentsOfFile:crashLogPath encoding:NSUTF8StringEncoding error:nil];
        if (!crashLog) {
            continue;
        }
        [_crashManager sendCrashReportWithFilename:crashLogPath xml:crashLog attachment:nil];
    }
}

- (BOOL)sendLiveCrashReport:(NSError **)error {
    return [self sendLiveCrashReportWithPayload:nil error:error];
}

- (BOOL)sendLiveCrashReportWithPayload:(nullable NSString *)payload
                                 error:(NSError **)error {
    NSData *report = [[BITPLCrashReporter sharedReporter] generateLiveReportAndReturnError:error];
    if (!report) {
        return NO;
    }
    return [self sendCrashReport:report withPayload:payload error:error];
}

- (BOOL)sendCrashReport:(NSData *)report
                  error:(NSError **)error {
    return [self sendCrashReport:report withPayload:nil error:error];
}

- (BOOL)sendCrashReport:(NSData *)report
            withPayload:(nullable NSString *)payload
                  error:(NSError **)error {
    BITPLCrashReport *crashReport = [[BITPLCrashReport alloc] initWithData:report error:error];
    if (!crashReport) {
        return NO;
    }
    NSString *crashLog = [self _crashLogForReport:crashReport withPayload:payload];
    NSString *crashLogPath = nil;
    if (_backupDirectoryPath) {
        crashLogPath = [[_backupDirectoryPath
                         stringByAppendingPathComponent:[[NSProcessInfo processInfo] globallyUniqueString]]
                         stringByAppendingPathExtension:@"xml"];
        [crashLog writeToFile:crashLogPath atomically:YES encoding:NSUTF8StringEncoding error:nil];
    }
    [_crashManager sendCrashReportWithFilename:crashLogPath xml:crashLog attachment:nil];
    return YES;
}

- (void)fireAssertReport:(NSData *)report withPayload:(NSString *)payload, ... {
    NSParameterAssert(payload);
    va_list args;
    va_start(args, payload);
    NSString *reason = [[NSString alloc] initWithFormat:payload arguments:args];
    va_end(args);
    [self sendCrashReport:report withPayload:reason error:nil];
}

#pragma mark Private

- (NSString *)_crashLogForReport:(BITPLCrashReport *)report
                     withPayload:(nullable NSString *)applicationLog {
    NSString *crashUUID = @"";
    if (report.uuidRef != NULL) {
        crashUUID = (NSString *)CFBridgingRelease(CFUUIDCreateString(NULL, report.uuidRef));
    }
    NSString *installID = bit_appAnonID(NO) ?: @"";
    NSString *crashReport = [BITCrashReportTextFormatter stringValueForCrashReport:(id)report
                                                                  crashReporterKey:installID];
    BITCrashManager *crashManager = BITHockeyManager.sharedHockeyManager.crashManager;
    NSString *userName = crashManager.userNameForCrashReport;
    NSString *userEmail = crashManager.userEmailForCrashReport;
    NSString *userID = crashManager.userIDForCrashReport;
    NSMutableString *description = [NSMutableString new];
    if ([applicationLog length] > 0) {
        [description appendString:applicationLog];
    }
    if ([crashManager.delegate respondsToSelector:@selector(applicationLogForCrashManager:)]) {
        NSString *fileLog = [crashManager.delegate applicationLogForCrashManager:crashManager];
        if (fileLog) {
            [description appendFormat:@"\n-----------\n%@", fileLog];
        }
    }
    return [NSString stringWithFormat:@
            "<crashes>"
                "<crash>"
                    "<applicationname>%s</applicationname>"
                    "<uuids>%@</uuids>"
                    "<bundleidentifier>%@</bundleidentifier>"
                    "<systemversion>%@</systemversion>"
                    "<platform>%@</platform>"
                    "<senderversion>%@</senderversion>"
                    "<version>%@</version>"
                    "<uuid>%@</uuid>"
                    "<log><![CDATA[%@]]></log>"
                    "<userid>%@</userid>"
                    "<username>%@</username>"
                    "<contact>%@</contact>"
                    "<installstring>%@</installstring>"
                    "<description><![CDATA[%@]]></description>"
                "</crash>"
            "</crashes>",
            [[[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleExecutable"] UTF8String],
            [self _extractAppUUIDs:report],
            report.applicationInfo.applicationIdentifier,
            report.systemInfo.operatingSystemVersion,
            [self.class _platform],
            [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"],
            report.applicationInfo.applicationVersion,
            crashUUID,
            [crashReport stringByReplacingOccurrencesOfString:@"]]>"
                                                   withString:@"]]" @"]]><![CDATA[" @">"
                                                      options:NSLiteralSearch
                                                        range:NSMakeRange(0, crashReport.length)],
            userID,
            userName,
            userEmail,
            installID,
            [description stringByReplacingOccurrencesOfString:@"]]>"
                                                   withString:@"]]" @"]]><![CDATA[" @">"
                                                      options:NSLiteralSearch
                                                        range:NSMakeRange(0,description.length)]];
}

- (NSString *)_extractAppUUIDs:(BITPLCrashReport *)report {
    NSMutableString *uuidString = [NSMutableString string];
    NSArray *uuidArray = [BITCrashReportTextFormatter arrayOfAppUUIDsForCrashReport:(id)report];
    for (NSDictionary *element in uuidArray) {
        if ([element objectForKey:kBITBinaryImageKeyUUID] &&
            [element objectForKey:kBITBinaryImageKeyArch] &&
            [element objectForKey:kBITBinaryImageKeyUUID]) {
            [uuidString appendFormat:@"<uuid type=\"%@\" arch=\"%@\">%@</uuid>",
             [element objectForKey:kBITBinaryImageKeyType],
             [element objectForKey:kBITBinaryImageKeyArch],
             [element objectForKey:kBITBinaryImageKeyUUID]];
        }
    }
    return uuidString;
}

+ (NSString *)_platform {
    size_t size;
    sysctlbyname("hw.machine", NULL, &size, NULL, 0);
    char *machine = malloc(size);
    sysctlbyname("hw.machine", machine, &size, NULL, 0);
    NSString *platform = [NSString stringWithUTF8String:machine];
    free(machine);
    return platform;
}

@end

NS_ASSUME_NONNULL_END
