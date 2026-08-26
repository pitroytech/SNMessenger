#import "SNDiagnostics.h"

#import <Cephei/HBPreferences.h>
#import <dlfcn.h>
#import <mach-o/dyld.h>
#import <objc/runtime.h>
#import <unistd.h>

NSString * const SNDiagnosticsDomain = @"com.nguyenasang.snmessenger.diagnostics";
NSString * const SNDiagnosticsReportKey = @"latestReport";
NSString * const SNDiagnosticsUpdatedKey = @"lastUpdated";
CFStringRef const SNDiagnosticsRunNotification = CFSTR("com.nguyenasang.snmessenger/RunDiagnostics");

static const NSUInteger kSNMaximumCandidateClasses = 160;
static const NSUInteger kSNMaximumCandidateMethods = 480;
static const NSUInteger kSNMaximumObservedControllers = 120;

static dispatch_queue_t gSNDiagnosticsQueue;
static HBPreferences *gSNDiagnosticsPreferences;
static NSMutableDictionary<NSString *, NSString *> *gSNSymbols;
static NSMutableOrderedSet<NSString *> *gSNObservedControllers;
static NSMutableArray<NSString *> *gSNSettingsEvents;
static NSArray<NSString *> *gSNCandidates;
static BOOL gSNFlushScheduled;
static NSString *gSNLastReason;
static NSDateFormatter *gSNDateFormatter;

extern NSBundle *tweakBundle;

static NSString *SNSettingsPath(void) {
    NSArray<NSString *> *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    return [[paths firstObject] stringByAppendingPathComponent:@"SNMessenger.plist"];
}

static NSString *SNReportPath(void) {
    NSArray<NSString *> *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    return [[paths firstObject] stringByAppendingPathComponent:@"SNMessengerDiagnostics.txt"];
}

static NSString *SNDateString(NSDate *date) {
    return [gSNDateFormatter stringFromDate:date] ?: @"unknown";
}

static BOOL SNContainsKeyword(NSString *value, NSArray<NSString *> *keywords) {
    for (NSString *keyword in keywords) {
        if ([value rangeOfString:keyword options:NSCaseInsensitiveSearch].location != NSNotFound) return YES;
    }
    return NO;
}

static NSString *SNMethodImage(Method method) {
    if (method == NULL) return @"(none)";
    Dl_info info = {};
    IMP implementation = method_getImplementation(method);
    if (implementation != NULL && dladdr((const void *)implementation, &info) != 0 && info.dli_fname != NULL) {
        return [NSString stringWithUTF8String:info.dli_fname].lastPathComponent ?: @"unknown";
    }
    return @"unknown";
}

static NSArray<NSString *> *SNHookInventory(void) {
    return @[
        @"MSGCommunityListViewController|_headerSectionCellConfigs",
        @"MDSNavigationController|viewWillAppear:",
        @"MSGSettingsViewController|viewDidAppear:",
        @"MSGModel|setValueForField:value:",
        @"MSGModel|valueAtFieldIndex:",
        @"LSMediaPickerViewController|collectionView:shouldSelectItemAtIndexPath:",
        @"MSGNavigationCoordinator_LSNavigationCoordinatorProxy|presentAlertWithCompletion:",
        @"MSGCQLResultSetList|newWithIdentifier:context:resultSet:resultSetCount:options:actionHandlers:impressionTrackingContext:",
        @"LSStoryBucketViewController|startTimer",
        @"LSStoryBucketViewController|replyBarWillPlayStoryFromBeginning:",
        @"MSGMetaAIFAB.MSGMetaAIFABViewController|viewDidLoad",
        @"MSGThreadListDataSource|initWithViewRendererContext:mailbox:config:",
        @"MSGThreadViewController|messageListViewControllerDidLongPressBackground:",
        @"LSMediaViewerViewController|prefersStatusBarHidden",
        @"MSGUniversalSearchNullStateViewController|_updateHeaderList:",
        @"LSContactListViewController|didLoadContactList:contactExtrasById:",
        @"LSTabBarDataSource|initWithDependencies:inboxLoadedCompletion:",
        @"MDSTabBarController|_prepareTabBar",
        @"MSGThreadRowCell|_isTypingWithModel:",
        @"MSGThreadRowCell|_isTypingWithModel:mailbox:",
        @"MSGInboxAdsUserScopedPlugin|MSGInboxAdsUnitFetcher_MSGFetchInboxUnit:",
        @"MSGThreadListDataSource|inboxRows",
        @"LSStoryViewerContentController|_updateStoriesWithBucketStoryModels:deletedIndexPaths:addedIndexPaths:newIndexPath:",
        @"LSStoryOverlayProfileView|_handleOverflowMenuButton:",
    ];
}

static void SNRunCandidateScanLocked(void) {
    NSArray<NSString *> *classKeywords = @[@"setting", @"profile", @"community", @"navigation", @"inbox", @"account", @"preference"];
    NSArray<NSString *> *methodKeywords = @[@"setting", @"profile", @"header", @"config", @"navigation", @"community", @"account"];
    NSMutableArray<NSString *> *result = [NSMutableArray array];

    int classCount = objc_getClassList(NULL, 0);
    if (classCount <= 0) {
        gSNCandidates = @[@"objc_getClassList returned no classes"];
        return;
    }

    Class *classes = (Class *)calloc((size_t)classCount, sizeof(Class));
    classCount = objc_getClassList(classes, classCount);
    NSUInteger matchedClasses = 0;
    NSUInteger matchedMethods = 0;

    for (int index = 0; index < classCount && matchedClasses < kSNMaximumCandidateClasses; index++) {
        Class cls = classes[index];
        const char *rawName = class_getName(cls);
        if (rawName == NULL) continue;
        NSString *className = [NSString stringWithUTF8String:rawName];
        if (!SNContainsKeyword(className, classKeywords)) continue;

        const char *rawImage = class_getImageName(cls);
        NSString *image = rawImage ? [NSString stringWithUTF8String:rawImage] : @"unknown";
        if ([image rangeOfString:NSBundle.mainBundle.bundlePath options:NSCaseInsensitiveSearch].location == NSNotFound) continue;

        matchedClasses++;
        [result addObject:[NSString stringWithFormat:@"class %@ image=%@", className, image.lastPathComponent]];

        unsigned int methodCount = 0;
        Method *methods = class_copyMethodList(cls, &methodCount);
        for (unsigned int methodIndex = 0; methodIndex < methodCount && matchedMethods < kSNMaximumCandidateMethods; methodIndex++) {
            SEL selector = method_getName(methods[methodIndex]);
            NSString *selectorName = NSStringFromSelector(selector);
            if (!SNContainsKeyword(selectorName, methodKeywords)) continue;
            const char *types = method_getTypeEncoding(methods[methodIndex]);
            [result addObject:[NSString stringWithFormat:@"  - %@ types=%s", selectorName, types ?: "?"]];
            matchedMethods++;
        }
        free(methods);
    }
    free(classes);

    if (result.count == 0) [result addObject:@"No settings/profile candidates found in Messenger images"];
    gSNCandidates = [result copy];
}

static void SNAppendHookMatrix(NSMutableString *report) {
    [report appendString:@"\n=== hook matrix ===\n"];
    for (NSString *entry in SNHookInventory()) {
        NSArray<NSString *> *parts = [entry componentsSeparatedByString:@"|"];
        NSString *className = parts.firstObject;
        NSString *selectorName = parts.lastObject;
        Class cls = objc_lookUpClass(className.UTF8String);
        Method method = cls ? class_getInstanceMethod(cls, NSSelectorFromString(selectorName)) : NULL;
        const char *types = method ? method_getTypeEncoding(method) : NULL;
        [report appendFormat:@"%@ %@ class=%d selector=%d types=%s image=%@\n",
            className,
            selectorName,
            cls != Nil,
            method != NULL,
            types ?: "?",
            SNMethodImage(method)];
    }
}

static void SNAppendLoadedImages(NSMutableString *report) {
    [report appendString:@"\n=== relevant loaded images ===\n"];
    for (uint32_t index = 0; index < _dyld_image_count(); index++) {
        const char *rawPath = _dyld_get_image_name(index);
        if (rawPath == NULL) continue;
        NSString *path = [NSString stringWithUTF8String:rawPath];
        if ([path rangeOfString:NSBundle.mainBundle.bundlePath].location == NSNotFound &&
            !SNContainsKeyword(path.lastPathComponent, @[@"LightSpeed", @"Messenger", @"MDS", @"MSG"])) continue;
        [report appendFormat:@"%@\n", path];
    }
}

static NSString *SNBuildReportLocked(void) {
    NSBundle *mainBundle = NSBundle.mainBundle;
    NSDictionary *info = mainBundle.infoDictionary ?: @{};
    NSString *settingsPath = SNSettingsPath();
    NSDictionary *settings = [NSDictionary dictionaryWithContentsOfFile:settingsPath];
    NSFileManager *fileManager = NSFileManager.defaultManager;
    NSMutableString *report = [NSMutableString string];

    [report appendString:@"SNMessenger diagnostics\n"];
    [report appendString:@"probeVersion: 2.1.0\n"];
    [report appendFormat:@"timestamp: %@\n", SNDateString([NSDate date])];
    [report appendFormat:@"lastReason: %@\n", gSNLastReason ?: @"startup"];
    [report appendFormat:@"process: %@ pid=%d\n", NSProcessInfo.processInfo.processName, getpid()];
    [report appendFormat:@"bundleID: %@\n", mainBundle.bundleIdentifier ?: @"unknown"];
    [report appendFormat:@"messengerVersion: %@ (%@)\n", info[@"CFBundleShortVersionString"] ?: @"unknown", info[@"CFBundleVersion"] ?: @"unknown"];
    [report appendFormat:@"bundlePath: %@\n", mainBundle.bundlePath ?: @"unknown"];
    [report appendFormat:@"home: %@\n", NSHomeDirectory()];
    [report appendFormat:@"tweakBundle: %@ exists=%d\n", tweakBundle.bundlePath ?: @"(nil)", tweakBundle.bundlePath ? [fileManager fileExistsAtPath:tweakBundle.bundlePath] : NO];
    [report appendFormat:@"settingsPath: %@ exists=%d readable=%d keys=%lu\n",
        settingsPath,
        [fileManager fileExistsAtPath:settingsPath],
        [fileManager isReadableFileAtPath:settingsPath],
        (unsigned long)settings.count];
    [report appendFormat:@"settingsKeys: %@\n", [[settings.allKeys sortedArrayUsingSelector:@selector(compare:)] componentsJoinedByString:@", "] ?: @""];
    [report appendFormat:@"reportPath: %@\n", SNReportPath()];
    [report appendString:@"sharedTransport: HBPreferences + app-container file fallback\n"];
    [report appendString:@"symbolFrameworksExpected: LightSpeedCore, LightSpeedEngine\n"];

    SNAppendHookMatrix(report);

    [report appendString:@"\n=== C symbols ===\n"];
    if (gSNSymbols.count == 0) {
        [report appendString:@"No symbol checks recorded\n"];
    } else {
        for (NSString *key in [gSNSymbols.allKeys sortedArrayUsingSelector:@selector(compare:)]) {
            [report appendFormat:@"%@ %@\n", key, gSNSymbols[key]];
        }
    }

    [report appendString:@"\n=== settings route events ===\n"];
    if (gSNSettingsEvents.count == 0) [report appendString:@"No settings route hook has fired\n"];
    for (NSString *event in gSNSettingsEvents) [report appendFormat:@"%@\n", event];

    [report appendString:@"\n=== observed view controllers ===\n"];
    if (gSNObservedControllers.count == 0) [report appendString:@"No view controller observed yet\n"];
    for (NSString *controller in gSNObservedControllers) [report appendFormat:@"%@\n", controller];

    [report appendString:@"\n=== settings/profile candidates ===\n"];
    if (gSNCandidates.count == 0) [report appendString:@"Candidate scan pending\n"];
    for (NSString *candidate in gSNCandidates) [report appendFormat:@"%@\n", candidate];

    SNAppendLoadedImages(report);
    return report;
}

static void SNFlushLocked(void) {
    NSString *report = SNBuildReportLocked();
    NSString *reportPath = SNReportPath();
    NSError *writeError = nil;
    [report writeToFile:reportPath atomically:YES encoding:NSUTF8StringEncoding error:&writeError];

    @try {
        [gSNDiagnosticsPreferences setObject:report forKey:SNDiagnosticsReportKey];
        [gSNDiagnosticsPreferences setObject:[NSDate date] forKey:SNDiagnosticsUpdatedKey];
        [gSNDiagnosticsPreferences setObject:reportPath forKey:@"appReportPath"];
        [gSNDiagnosticsPreferences setObject:writeError.localizedDescription ?: @"ok" forKey:@"appReportWrite"];
    } @catch (NSException *exception) {
        NSLog(@"[SNMessenger] diagnostics transport exception=%@ reason=%@", exception.name, exception.reason);
    }
}

static void SNScheduleFlushLocked(NSString *reason) {
    gSNLastReason = [reason copy];
    if (gSNFlushScheduled) return;
    gSNFlushScheduled = YES;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.75 * NSEC_PER_SEC)), gSNDiagnosticsQueue, ^{
        gSNFlushScheduled = NO;
        SNFlushLocked();
    });
}

static void SNRunScanLocked(NSString *reason) {
    gSNCandidates = nil;
    SNRunCandidateScanLocked();
    SNScheduleFlushLocked(reason);
}

static void SNDiagnosticsRequestCallback(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    dispatch_async(gSNDiagnosticsQueue, ^{
        SNRunScanLocked(@"external scan request");
    });
}

void SNDiagnosticsStart(void) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        gSNDiagnosticsQueue = dispatch_queue_create("com.nguyenasang.snmessenger.diagnostics", DISPATCH_QUEUE_SERIAL);
        gSNDiagnosticsPreferences = [[HBPreferences alloc] initWithIdentifier:SNDiagnosticsDomain];
        gSNSymbols = [NSMutableDictionary dictionary];
        gSNObservedControllers = [NSMutableOrderedSet orderedSet];
        gSNSettingsEvents = [NSMutableArray array];
        gSNDateFormatter = [[NSDateFormatter alloc] init];
        gSNDateFormatter.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
        gSNDateFormatter.dateFormat = @"yyyy-MM-dd HH:mm:ss Z";

        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, SNDiagnosticsRequestCallback, SNDiagnosticsRunNotification, NULL, CFNotificationSuspensionBehaviorDeliverImmediately);

        dispatch_async(dispatch_get_main_queue(), ^{
            NSNotificationCenter *center = NSNotificationCenter.defaultCenter;
            [center addObserverForName:UIApplicationDidFinishLaunchingNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:^(__unused NSNotification *note) {
                dispatch_async(gSNDiagnosticsQueue, ^{ SNRunScanLocked(@"application did finish launching"); });
            }];
            [center addObserverForName:UIApplicationDidBecomeActiveNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:^(__unused NSNotification *note) {
                dispatch_async(gSNDiagnosticsQueue, ^{ SNScheduleFlushLocked(@"application became active"); });
            }];
        });

        dispatch_async(gSNDiagnosticsQueue, ^{ SNRunScanLocked(@"constructor"); });
    });
}

void SNDiagnosticsFlush(NSString *reason) {
    if (gSNDiagnosticsQueue == nil) return;
    dispatch_async(gSNDiagnosticsQueue, ^{ SNScheduleFlushLocked(reason ?: @"manual"); });
}

void SNDiagnosticsRecordSymbol(NSString *framework, const char *symbol, BOOL found, const void *address) {
    if (gSNDiagnosticsQueue == nil) return;
    NSString *symbolName = symbol ? [NSString stringWithUTF8String:symbol] : @"(null)";
    dispatch_async(gSNDiagnosticsQueue, ^{
        NSString *key = [NSString stringWithFormat:@"%@:%@", framework ?: @"unknown", symbolName];
        gSNSymbols[key] = [NSString stringWithFormat:@"found=%d address=%p", found, address];
        SNScheduleFlushLocked(@"symbol resolution");
    });
}

void SNDiagnosticsRecordSettingsEntry(NSString *source, id controller, NSInteger itemCount) {
    if (gSNDiagnosticsQueue == nil) return;
    NSString *sourceName = [source copy] ?: @"unknown";
    NSString *controllerName = controller ? NSStringFromClass([controller class]) : @"(nil)";
    dispatch_async(gSNDiagnosticsQueue, ^{
        NSString *event = [NSString stringWithFormat:@"%@ source=%@ controller=%@ itemCount=%ld",
            SNDateString([NSDate date]), sourceName, controllerName, (long)itemCount];
        if (gSNSettingsEvents.count >= 80) [gSNSettingsEvents removeObjectAtIndex:0];
        [gSNSettingsEvents addObject:event];
        SNScheduleFlushLocked(@"settings route hook");
    });
}

void SNDiagnosticsRecordViewController(UIViewController *controller) {
    if (gSNDiagnosticsQueue == nil || controller == nil) return;
    NSString *className = NSStringFromClass(controller.class);
    NSMutableArray<NSString *> *stack = [NSMutableArray array];
    for (UIViewController *item in controller.navigationController.viewControllers) {
        [stack addObject:NSStringFromClass(item.class)];
    }
    NSString *line = [NSString stringWithFormat:@"%@ nav=[%@]", className, [stack componentsJoinedByString:@" > "]];
    dispatch_async(gSNDiagnosticsQueue, ^{
        if (![gSNObservedControllers containsObject:line]) {
            if (gSNObservedControllers.count >= kSNMaximumObservedControllers) [gSNObservedControllers removeObjectAtIndex:0];
            [gSNObservedControllers addObject:line];
            SNScheduleFlushLocked(@"view controller appeared");
        }
    });
}
