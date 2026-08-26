#import "SNRootListController.h"

#import <Cephei/HBPreferences.h>
#import <Preferences/PSSpecifier.h>
#import <UIKit/UIKit.h>

static NSString * const SNDiagnosticsDomain = @"com.nguyenasang.snmessenger.diagnostics";
static NSString * const SNDiagnosticsReportKey = @"latestReport";
static NSString * const SNDiagnosticsUpdatedKey = @"lastUpdated";
static CFStringRef const SNDiagnosticsRunNotification = CFSTR("com.nguyenasang.snmessenger/RunDiagnostics");

@interface LSApplicationProxy : NSObject
+ (instancetype)applicationProxyForIdentifier:(NSString *)identifier;
@property (nonatomic, readonly) NSURL *dataContainerURL;
@end

@implementation SNRootListController

- (NSArray *)specifiers {
    if (_specifiers == nil) {
        _specifiers = [self loadSpecifiersFromPlistName:@"Root" target:self];
    }
    return _specifiers;
}

- (NSString *)localized:(NSString *)key {
    return [self.bundle localizedStringForKey:key value:key table:@"Root"];
}

- (NSString *)messengerReportPath {
    LSApplicationProxy *proxy = [LSApplicationProxy applicationProxyForIdentifier:@"com.facebook.Messenger"];
    NSString *containerPath = proxy.dataContainerURL.path;
    if (containerPath.length > 0) {
        return [[containerPath stringByAppendingPathComponent:@"Documents"] stringByAppendingPathComponent:@"SNMessengerDiagnostics.txt"];
    }

    NSString *containersRoot = @"/var/mobile/Containers/Data/Application";
    for (NSString *identifier in [NSFileManager.defaultManager contentsOfDirectoryAtPath:containersRoot error:nil]) {
        NSString *container = [containersRoot stringByAppendingPathComponent:identifier];
        NSString *metadataPath = [container stringByAppendingPathComponent:@".com.apple.mobile_container_manager.metadata.plist"];
        NSDictionary *metadata = [NSDictionary dictionaryWithContentsOfFile:metadataPath];
        if ([metadata[@"MCMMetadataIdentifier"] isEqualToString:@"com.facebook.Messenger"]) {
            return [[container stringByAppendingPathComponent:@"Documents"] stringByAppendingPathComponent:@"SNMessengerDiagnostics.txt"];
        }
    }
    return nil;
}

- (NSDictionary<NSString *, id> *)reportAndSource {
    HBPreferences *preferences = [[HBPreferences alloc] initWithIdentifier:SNDiagnosticsDomain];
    NSString *report = [preferences objectForKey:SNDiagnosticsReportKey];
    if ([report isKindOfClass:NSString.class] && report.length > 0) {
        return @{ @"report": report, @"source": @"HBPreferences" };
    }

    NSString *path = [self messengerReportPath];
    NSError *error = nil;
    NSString *fileReport = path ? [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:&error] : nil;
    if (fileReport.length > 0) {
        return @{ @"report": fileReport, @"source": @"Messenger Documents" };
    }

    NSString *fallback = [NSString stringWithFormat:
        @"SNMessenger Settings-side diagnostics\n"
         "timestamp: %@\n"
         "sharedReport: missing\n"
         "containerReportPath: %@\n"
         "containerReadable: %d\n"
         "containerError: %@\n"
         "instruction: Open Messenger, visit Inbox/Profile, then return here and tap Refresh Report.\n",
        [NSDate date],
        path ?: @"not resolved",
        path ? [NSFileManager.defaultManager isReadableFileAtPath:path] : NO,
        error.localizedDescription ?: @"none"];
    return @{ @"report": fallback, @"source": @"Settings fallback" };
}

- (NSString *)statusValue:(PSSpecifier *)specifier {
    (void)specifier;
    NSDictionary *payload = [self reportAndSource];
    NSString *source = payload[@"source"];
    NSString *report = payload[@"report"];
    if ([source isEqualToString:@"Settings fallback"]) return [self localized:@"No Messenger report yet"];

    NSRange range = [report rangeOfString:@"timestamp: "];
    if (range.location != NSNotFound) {
        NSString *tail = [report substringFromIndex:NSMaxRange(range)];
        NSString *timestamp = [[tail componentsSeparatedByCharactersInSet:NSCharacterSet.newlineCharacterSet] firstObject];
        return [NSString stringWithFormat:@"%@ · %@", source, timestamp ?: @""];
    }
    return source;
}

- (void)reloadStatus {
    [self reloadSpecifiers];
}

- (void)refreshReport {
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), SNDiagnosticsRunNotification, NULL, NULL, YES);
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self reloadStatus];
    });
}

- (void)copyReport {
    UIPasteboard.generalPasteboard.string = [self reportAndSource][@"report"];
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:[self localized:@"Copied"] message:nil preferredStyle:UIAlertControllerStyleAlert];
    [self presentViewController:alert animated:YES completion:^{
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.7 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [alert dismissViewControllerAnimated:YES completion:nil];
        });
    }];
}

- (void)shareReport {
    NSString *report = [self reportAndSource][@"report"];
    NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:@"SNMessenger-diagnostics.txt"];
    [report writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:nil];
    UIActivityViewController *controller = [[UIActivityViewController alloc] initWithActivityItems:@[[NSURL fileURLWithPath:path]] applicationActivities:nil];
    if (controller.popoverPresentationController != nil) {
        controller.popoverPresentationController.sourceView = self.view;
        controller.popoverPresentationController.sourceRect = CGRectMake(CGRectGetMidX(self.view.bounds), CGRectGetMidY(self.view.bounds), 1, 1);
    }
    [self presentViewController:controller animated:YES completion:nil];
}

- (void)clearReport {
    HBPreferences *preferences = [[HBPreferences alloc] initWithIdentifier:SNDiagnosticsDomain];
    @try {
        [preferences removeObjectForKey:SNDiagnosticsReportKey];
        [preferences removeObjectForKey:SNDiagnosticsUpdatedKey];
    } @catch (__unused NSException *exception) {
    }
    NSString *path = [self messengerReportPath];
    if (path.length > 0) [NSFileManager.defaultManager removeItemAtPath:path error:nil];
    [self reloadStatus];
}

@end
