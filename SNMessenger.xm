#import "Settings/SNSettingsViewController.h"
#import "Diagnostics/SNDiagnostics.h"
#import "SNMessenger.h"

#pragma mark - Global variables & functions

static BOOL noAds;
static BOOL showTheEyeButton;
static BOOL alwaysSendHdPhotos;
static BOOL callConfirmation;
static BOOL disableLongPressToChangeChatTheme;
static BOOL disableReadReceipts;
static BOOL disableTypingIndicator;
static NSString *hideTypingIndicator;
static BOOL hideNotifBadgesInChat;
static NSString *keyboardStateAfterEnterChat;
static BOOL canSaveFriendsStories;
static BOOL disableStoriesPreview;
static BOOL disableStorySeenReceipts;
static BOOL extendStoryVideoUploadLength;
static BOOL hideStatusBarWhenViewingStory;
static BOOL neverReplayStoryAfterReacting;
static BOOL hideMetaAIFloatingButton;
static BOOL hideNotesRow;
static BOOL hidePeopleTab;
static BOOL hideStoriesTab;
static BOOL hideSearchBar;
static BOOL hideSuggestionsInSearch;
static NSMutableDictionary *settings;

BOOL isDarkMode = NO;
NSBundle *tweakBundle = nil;

static NSBundle *SNMessengerBundle() {
    static NSBundle *bundle = nil;
    static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
        NSString *tweakBundlePath = [[NSBundle mainBundle] pathForResource:@"SNMessenger" ofType:@"bundle"];
        if (tweakBundlePath)
            bundle = [NSBundle bundleWithPath:tweakBundlePath];
        else
            bundle = [NSBundle bundleWithPath:ROOT_PATH_NS(@"/Library/Application Support/SNMessenger.bundle")];
    });

    return bundle;
}

static void reloadPrefs() {
    settings = getCurrentSettings();

    noAds                             = [[settings objectForKey:@"noAds"] ?: @(YES) boolValue];
    showTheEyeButton                  = [[settings objectForKey:@"showTheEyeButton"] ?: @(YES) boolValue];

    alwaysSendHdPhotos                = [[settings objectForKey:@"alwaysSendHdPhotos"] ?: @(YES) boolValue];
    callConfirmation                  = [[settings objectForKey:@"callConfirmation"] ?: @(YES) boolValue];
    disableReadReceipts               = [[settings objectForKey:@"disableReadReceipts"] ?: @(YES) boolValue];
    disableLongPressToChangeChatTheme = [[settings objectForKey:@"disableLongPressToChangeTheme"] ?: @(NO) boolValue];
    disableTypingIndicator            = [[settings objectForKey:@"disableTypingIndicator"] ?: @(NO) boolValue];
    hideTypingIndicator               = [ settings objectForKey:@"hideTypingIndicator"] ?: @"NOWHERE";
    hideNotifBadgesInChat             = [[settings objectForKey:@"hideNotifBadgesInChat"] ?: @(NO) boolValue];
    keyboardStateAfterEnterChat       = [ settings objectForKey:@"keyboardStateAfterEnterChat"] ?: @"ADAPTIVE";

    canSaveFriendsStories             = [[settings objectForKey:@"canSaveFriendsStories"] ?: @(YES) boolValue];
    disableStoriesPreview             = [[settings objectForKey:@"disableStoriesPreview"] ?: @(NO) boolValue];
    disableStorySeenReceipts          = [[settings objectForKey:@"disableStorySeenReceipts"] ?: @(YES) boolValue];
    extendStoryVideoUploadLength      = [[settings objectForKey:@"extendStoryVideoUploadLength"] ?: @(YES) boolValue];
    hideStatusBarWhenViewingStory     = [[settings objectForKey:@"hideStatusBarWhenViewingStory"] ?: @(YES) boolValue];
    neverReplayStoryAfterReacting     = [[settings objectForKey:@"neverReplayStoryAfterReacting"] ?: @(NO) boolValue];

    hideMetaAIFloatingButton          = [[settings objectForKey:@"hideMetaAIFloatingButton"] ?: @(NO) boolValue];
    hideNotesRow                      = [[settings objectForKey:@"hideNotesRow"] ?: @(NO) boolValue];
    hidePeopleTab                     = [[settings objectForKey:@"hidePeopleTab"] ?: @(NO) boolValue];
    hideStoriesTab                    = [[settings objectForKey:@"hideStoriesTab"] ?: @(NO) boolValue];
    hideSearchBar                     = [[settings objectForKey:@"hideSearchBar"] ?: @(NO) boolValue];
    hideSuggestionsInSearch           = [[settings objectForKey:@"hideSuggestionsInSearch"] ?: @(NO) boolValue];
}

MDSColorTypeMdsColor *(* _MDSColorTypeMdsColorCreate)(NSUInteger);
MDSGeneratedImageIconStyleNormal *(* _MDSGeneratedImageIconStyleNormalCreate)();
MDSGeneratedImageSpecIcon *(* _MDSGeneratedImageSpecIconCreate)(NSUInteger, MDSColorTypeMdsColor *, id);

MDSGeneratedImageView *MDSGeneratedImageViewCreate(NSString *iconName, NSUInteger colorCode, CGSize size) {
    // Get icon code (Hard-coded in `MDSIconNameString`)
    NSUInteger iconCode = 0;
    SwitchStr (iconName) {
        CaseEqual (@"CautionTriangle") {
            iconCode = 119736542;
            break;
        }

        CaseEqual (@"Checkmark") {
            iconCode = 377961600;
            break;
        }

        CaseEqual (@"ChevronRight") {
            iconCode = 872221393;
            break;
        }

        CaseEqual (@"Eye") {
            iconCode = 27507802;
            break;
        }

        CaseEqual (@"EyeCross") {
            iconCode = 273785350;
            break;
        }

        Default {
            break;
        }
    }

    // Fix color code in older versions
    if (SNTraits().remapsMdsColorCodes) {
        switch (colorCode) {
            case 10093: {
                colorCode = 10096;
                break;
            }

            case 10094: {
                colorCode = 10082;
                break;
            }

            case 10096: {
                colorCode = 10098;
                break;
            }

            default: break;
        }
    }

    MDSColorTypeMdsColor *color = _MDSColorTypeMdsColorCreate(colorCode);
    MDSGeneratedImageSpecIcon *spec = _MDSGeneratedImageSpecIconCreate(iconCode, color, _MDSGeneratedImageIconStyleNormalCreate());
    MDSGeneratedImageView *imageView = [[%c(MDSGeneratedImageView) alloc] initWithFrame:{{0, 0}, size}];
    [imageView setSpec:spec];
    return imageView;
}

static BOOL SNIsMessengerSettingsController(UIViewController *controller) {
    NSString *className = NSStringFromClass(controller.class);
    return [className isEqualToString:@"MSGSettingsViewController"]
        || [className isEqualToString:@"MSGPrimarySettingsViewController"]
        || [className hasSuffix:@".MSGSettingsViewController"]
        || [className hasSuffix:@".MSGPrimarySettingsViewController"];
}

static void SNInstallSettingsButtonIfNeeded(UIViewController *controller) {
    if (!SNIsMessengerSettingsController(controller)) return;

    UIViewController *host = controller.navigationController.topViewController ?: controller;
    SEL action = @selector(snmessenger_openTweakSettings:);
    NSArray<UIBarButtonItem *> *currentItems = host.navigationItem.rightBarButtonItems ?: @[];
    for (UIBarButtonItem *item in currentItems) {
        if (item.target == host && item.action == action) return;
    }

    UIBarButtonItem *settingsButton = [[UIBarButtonItem alloc]
        initWithTitle:@"SN"
        style:UIBarButtonItemStylePlain
        target:host
        action:action];
    settingsButton.accessibilityLabel = @"SNMessenger Settings";

    NSMutableArray<UIBarButtonItem *> *items = [currentItems mutableCopy];
    [items addObject:settingsButton];
    host.navigationItem.rightBarButtonItems = items;
    SNDiagnosticsRecordSettingsEntry(@"installed direct settings button", host, (NSInteger)items.count);
}

#pragma mark - Settings page | Quick toggle to disable/enable read receipts

%hook MSGCommunityListViewController

- (NSMutableArray *)_headerSectionCellConfigs {
    NSMutableArray *cellConfigs = %orig;
    SNDiagnosticsRecordSettingsEntry(@"MSGCommunityListViewController._headerSectionCellConfigs", self, (NSInteger)cellConfigs.count);
    if ([cellConfigs count] == 3) {
        NSArray *folders = MSHookIvar<NSArray *>(self, "_folders");
        MSGInboxFolderListItemInfoFolder *settingsConfig = [[folders firstObject] copy];
        [settingsConfig setValueForField:@"folderName", localizedStringForKey(@"ADVANCED_SETTINGS")];
        [settingsConfig setValueForField:@"dispatchKey", @"advanced_settings_folder"];
        [settingsConfig setValueForField:@"mdsIconName", 119736542]; // Hard-coded in `MDSIconNameString`
        [settingsConfig setValueForField:@"badgeCount", 0];

        LSTableViewCellConfig *settingsCell = [[self getTableViewCellConfigs:@[settingsConfig] shouldRenderCMPresence:NO] firstObject];
        [settingsCell setValueForField:@"actionHandler", ^{ [self showTweakSettings]; }];

        [cellConfigs insertObject:[[cellConfigs lastObject] copy] atIndex:0]; // Space cell
        [cellConfigs insertObject:settingsCell atIndex:0];
    }

    return cellConfigs;
}

%new(v@:)
- (void)showTweakSettings {
    isDarkMode = MSHookIvar<NSInteger>(self.navigationController, "_statusBarStyleFromTheme") == 1;
    SNSettingsViewController *settingsController = [[SNSettingsViewController alloc] init];
    [self.navigationController pushViewController:settingsController animated:YES];
}

%end

%hook MDSNavigationController
%property (nonatomic, retain) UIBarButtonItem *eyeItem;
%property (nonatomic, retain) UIBarButtonItem *settingsItem;

- (void)viewWillAppear:(BOOL)arg1 {
    SNDiagnosticsRecordSettingsEntry(@"MDSNavigationController.viewWillAppear", self, (NSInteger)self.viewControllers.count);
    // v458.0.0 (old UI)
    if (!self.settingsItem && [SNChildViewControllerForUserInterfaceStyle(self) isKindOfClass:%c(MSGSettingsViewController)]) {
        UIButton *settingsButton = [[UIButton alloc] init];
        UIImage *settingsIcon = [MDSGeneratedImageViewCreate(@"CautionTriangle", 10096, {24, 24}) image];
        [settingsButton setImage:settingsIcon forState:UIControlStateNormal];
        [settingsButton addTarget:self action:@selector(openSettings) forControlEvents:UIControlEventTouchUpInside];
        self.settingsItem = [[UIBarButtonItem alloc] initWithCustomView:settingsButton];
        self.settingsItem.style = UIBarButtonItemStyleDone;

        @try {
            self.navigationBar.topItem.leftBarButtonItems = @[self.navigationBar.topItem.leftBarButtonItem, self.settingsItem];
        } @catch (id ex) {
            self.navigationBar.topItem.leftBarButtonItem = self.settingsItem;
        }
    }

    if (showTheEyeButton && !self.eyeItem && [SNChildViewControllerForUserInterfaceStyle(self) isKindOfClass:%c(MSGInboxViewController)]) {
        UIButton *eyeButton = [[UIButton alloc] init];
        UIImage *eyeIcon = [MDSGeneratedImageViewCreate(disableReadReceipts ? @"EyeCross" : @"Eye", 10093, {24, 24}) image];
        [eyeButton setImage:eyeIcon forState:UIControlStateNormal];
        [eyeButton addTarget:self action:@selector(handleEyeTap:) forControlEvents:UIControlEventTouchUpInside];
        self.eyeItem = [[UIBarButtonItem alloc] initWithCustomView:eyeButton];
        self.eyeItem.style = UIBarButtonItemStyleDone;

        self.navigationBar.topItem.rightBarButtonItems = @[self.navigationBar.topItem.rightBarButtonItem, self.eyeItem];
    }

    %orig;
}

%new(v@:)
- (void)openSettings {
    isDarkMode = MSHookIvar<NSInteger>(self, "_statusBarStyleFromTheme") == 1;
    SNSettingsViewController *settingsController = [[SNSettingsViewController alloc] init];
    [self pushViewController:settingsController animated:YES];
}

%new(v@:@)
- (void)handleEyeTap:(UIButton *)eyeButton {
    UIImage *eyeIcon = [MDSGeneratedImageViewCreate(!disableReadReceipts ? @"EyeCross" : @"Eye", 10093, {24, 24}) image];
    [eyeButton setImage:eyeIcon forState:UIControlStateNormal];

    [settings setObject:[NSNumber numberWithBool:!disableReadReceipts] forKey:@"disableReadReceipts"];
    [settings writeToFile:getSettingsPlistPath() atomically:YES];
    notify_post(PREF_CHANGED_NOTIF);
}

%end

#pragma mark - Necessary hooks

Class actionStandardClass;
MSGModelInfo actionStandardInfo = {};
MSGModelADTInfo actionStandardADTInfo = {
    .name = "MSGStoryOverlayProfileViewAction",
    .subtype = 0
};

Class actionTypeSaveClass;
MSGModelInfo actionTypeSaveInfo = {
    .name = "MSGStoryViewerOverflowMenuActionTypeSave",
    .numberOfFields = 0,
    .fieldInfo = nil,
    .resultSet = nil,
    .var4 = YES,
    .var5 = nil
};
MSGModelADTInfo actionTypeSaveADTInfo = {
    .name = "MSGStoryViewerOverflowMenuActionType",
    .subtype = 2
};

Class (* _MSGModelDefineClass)(MSGModelInfo *);
Class MSGModelDefineClass(MSGModelInfo *info) {
    Class modelClass = _MSGModelDefineClass(info);

    SwitchCStr (info->name) {
        CaseCEqual ("MSGStoryOverlayProfileViewActionStandard") {
            actionStandardClass = modelClass;
            actionStandardInfo = *info;
            break;
        }

        CaseCEqual ("MSGStoryViewerOverflowMenuActionTypeSave") {
            return objc_lookUpClass("MSGStoryViewerOverflowMenuActionTypeSave") ?: modelClass;
        }

        Default {
            break;
        }
    }

    return modelClass;
}

%hook MSGModel

%new(v@:@)
- (void)setValueForField:(NSString *)name, /* value: */ ... {
    MSGModelInfo *info = MSHookIvar<MSGModelInfo *>(self, "_modelInfo");
    NSInteger index = 0, type = -1, offset = 0x0;
    const char *encoding = "";

    while (index < info->numberOfFields) {
        if ([name isEqual:*(&info->fieldInfo->field_0 + offset)]) {
            encoding = *(&info->fieldInfo->encoding_0 + offset);
            type = *(&info->fieldInfo->type_0 + offset) % 256;
            break;
        }

        offset += 0x4;
        index++;
    };

    va_list args;
    va_start(args, name);

    switch (type) {
        case 0: {
            [self setBoolValue:(BOOL)va_arg(args, int) forFieldIndex:index];
            break;
        }

        case 2: {
            [self setInt64Value:va_arg(args, NSInteger) forFieldIndex:index];
            break;
        }

        case 5 ... 6: {
            switch (type - SNTraits().fieldTypeShift) {
                case 5: [self setObjectValue:va_arg(args, id) forFieldIndex:index];
                default: break;
            }

            break;
        }

        default: {
            RLog(@"model: %@ | field: %@ | type: %lu | encoding: %s", self, name, type, encoding);
            break;
        }
    }

    va_end(args);
}

%new(@@:Q)
- (id)valueAtFieldIndex:(NSUInteger)index {
    MSGModelInfo *modelInfo = MSHookIvar<MSGModelInfo *>(self, "_modelInfo");
    NSUInteger type = *(&modelInfo->fieldInfo->type_0 + 0x4 * index) % 256;
    MSGModelTypes values = MSHookIvar<MSGModelTypes>(self, "_fieldValues");

    if (index >= modelInfo->numberOfFields) return @"Out of fields.";

    switch (type) {
        case 0: return @(get<bool>(values[index]));
        case 1: return @(get<int>(values[index]));
        case 2: return @(get<long long>(values[index]));
        case 3: return @(get<double>(values[index]));
        case 4: return @(get<float>(values[index]));

        case 5 ... 8: {
            switch (type - SNTraits().fieldTypeShift) {
                case 4: return [NSValue valueWithPointer:get<void *>(values[index])]; // Struct in v458.0.0
                case 5: return get<id>(values[index]);
                case 6: return [get<MSGModelWeakObjectContainer *>(values[index]) value];
                case 7: return (__bridge id)get<void *>(values[index]);
                case 8: return NSStringFromSelector(*get<SEL *>(values[index]));
                default: break;
            }
        }

        case 9 ... 13: return get<id>(values[index]);
        default: break;
    }

    return nil;
}

%new(@@:)
- (NSMutableDictionary *)debugMSGModel {
    MSGModelInfo *modelInfo = MSHookIvar<MSGModelInfo *>(self, "_modelInfo");
    NSMutableDictionary *debugInfo = [@{} mutableCopy];
    NSInteger index = 0, offset = 0x0;

    while (index < modelInfo->numberOfFields) {
        NSString *name = *(&modelInfo->fieldInfo->field_0 + offset);
        NSUInteger size = *(&modelInfo->fieldInfo->sizeof_0 + offset);
        NSUInteger type = *(&modelInfo->fieldInfo->type_0 + offset) % 256;
        const char *encoding = *(&modelInfo->fieldInfo->encoding_0 + offset);

        NSDictionary *info = @{
            @"index": @(index),
            @"name" : name,
            @"size" : @(size),
            @"type" : [NSString stringWithFormat:@"type: %lu - %@ (%s)", type, typeLookup(encoding, type), encoding],
            @"value": [self valueAtFieldIndex:index] ?: [NSNull null]
        };
        [debugInfo setValue:info forKey:[NSString stringWithFormat:@"%lu - %@", index, name]];

        offset += 0x4;
        index++;
    };

    return debugInfo;
}

%end

#pragma mark - Always send HD photos

%hook LSMediaPickerViewController

- (BOOL)collectionView:(id)arg1 shouldSelectItemAtIndexPath:(id)arg2 {
    UIButton *hdToggleButton = MSHookIvar<UIButton *>(self, "_hdToggleButton");
    if (alwaysSendHdPhotos && [hdToggleButton state] == 0) {
        [self _didTapHDToggle:hdToggleButton];
    }

    return %orig;
}

%end

#pragma mark - Audio / Video call confirmation

%hook MSGNavigationCoordinator_LSNavigationCoordinatorProxy

%new(v@:@?)
- (void)presentAlertWithCompletion:(void (^)(BOOL confirmed))completion {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:localizedStringForKey(@"CALL_CONFIRMATION_TITLE") message:localizedStringForKey(@"CALL_CONFIRMATION_MESSAGE") preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:localizedStringForKey(@"CONFIRM") style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
        completion(YES);
    }]];

    [alert addAction:[UIAlertAction actionWithTitle:localizedStringForKey(@"CANCEL") style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {
        completion(NO);
    }]];

    [self presentViewController:alert presentationStyle:UIModalPresentationNone animated:YES completion:nil];
}

%end

id (* _LSRTCValidateCallIntentForKey)(NSString *, id, LSRTCCallIntentValidatorParams *);
id LSRTCValidateCallIntentForKey(NSString *key, id context, LSRTCCallIntentValidatorParams *params) {
    MSGNavigationCoordinator_LSNavigationCoordinatorProxy *navigationCoordinator = [[params callIntent] navigationCoordinator];
    if (!callConfirmation || ![key isEqual:@"rtc_integrity_joiner_transparency"]) {
        return _LSRTCValidateCallIntentForKey(key, context, params);
    }

    [navigationCoordinator presentAlertWithCompletion:^(BOOL confirmed) {
        if (confirmed) _LSRTCValidateCallIntentForKey(key, context, params);
    }];

    return nil;
}

#pragma mark - Disable read receipts

void (* _MCQSHIMTransportHybridThreadMarkThreadRead)();
void MCQSHIMTransportHybridThreadMarkThreadRead() {
    if (!disableReadReceipts) _MCQSHIMTransportHybridThreadMarkThreadRead();
}

// v458.0.0
void *(* _MCINotificationCenterPostStrictNotification)(NSUInteger, id, NSString *, NSString *, NSMutableDictionary *);
void *MCINotificationCenterPostStrictNotification(NSUInteger type, id notifCenter, NSString *event, NSString *taskID, NSMutableDictionary *content) {
    if (disableReadReceipts && [[content valueForKey:@"MCDNotificationTaskLabelsListKey"] isEqual:@[@"tam_thread_mark_read"]]) {
        return nil;
    }

    return _MCINotificationCenterPostStrictNotification(type, notifCenter, event, taskID, content);
}

#pragma mark - Disable stories preview

%hook MSGCQLResultSetList

+ (instancetype)newWithIdentifier:(NSString *)identifier context:(MSGStoryCardToolbox *)context resultSet:(id)arg3 resultSetCount:(NSInteger)arg4 options:(void *)arg5 actionHandlers:(void *)arg6 impressionTrackingContext:(id)arg7 {
    if ([identifier isEqual:@"stories"]) {
        [context setValueForField:@"isVideoAutoplayEnabled", !disableStoriesPreview];
    }

    return %orig;
}

%end

#pragma mark - Disable story seen receipt | Disable story replay after reacting

%hook LSStoryBucketViewController

- (void)startTimer {
    if (!disableStorySeenReceipts) return %orig;

    // Here we simply invoke [super startTimer] to do the timming job
    struct objc_super superInfo = {
        .receiver = self,
        .super_class = %c(LSStoryBucketViewControllerBase)
    };

    void (* startTimerSuper)(struct objc_super *, SEL) = (void (*)(struct objc_super *, SEL))objc_msgSendSuper;
    startTimerSuper(&superInfo, @selector(startTimer));
}

- (void)replyBarWillPlayStoryFromBeginning:(id)arg1 {
    if (!neverReplayStoryAfterReacting) {
        %orig;
    }
}

%end

#pragma mark - Disable typing indicator

void (* _MCQTamClientTypingIndicatorStart)();
void MCQTamClientTypingIndicatorStart() {
    if (!disableTypingIndicator) return _MCQTamClientTypingIndicatorStart();
}

#pragma mark - Extend story video upload duration

id (* _MSGAVFoundationEstimateMaxVideoDurationInputCreate)(MSGMediaVideoPhasset *, NSUInteger, NSInteger, id, id);
id MSGAVFoundationEstimateMaxVideoDurationInputCreate(MSGMediaVideoPhasset *videoAsset, NSUInteger maxVideoResolution, NSInteger maxFileSizeInBytes, id roundingFactorInSeconds, id completion) {
    if (extendStoryVideoUploadLength) MSHookIvar<CGFloat>([videoAsset asset], "_duration") = 1.0f; // max ≈ 13 mins
    return _MSGAVFoundationEstimateMaxVideoDurationInputCreate(videoAsset, maxVideoResolution, maxFileSizeInBytes, roundingFactorInSeconds, completion);
}

// v458.0.0
BOOL (* _MSGCSessionedMobileConfigGetBoolean)(id, MSGCSessionedMobileConfig *, BOOL, BOOL);
BOOL MSGCSessionedMobileConfigGetBoolean(id context, MSGCSessionedMobileConfig *config, BOOL arg3, BOOL arg4) {
    if (extendStoryVideoUploadLength && strcmp(config->subKey, "replace_system_trimmer") == 0) {
        return YES;
    }

    return _MSGCSessionedMobileConfigGetBoolean(context, config, arg3, arg4);
}

CGFloat (* _MSGCSessionedMobileConfigGetDouble)(id, MSGCSessionedMobileConfig *, BOOL, BOOL);
CGFloat MSGCSessionedMobileConfigGetDouble(id context, MSGCSessionedMobileConfig *config, BOOL arg3, BOOL arg4) {
    if (extendStoryVideoUploadLength && strcmp(config->subKey, "max_story_duration") == 0) {
        return 600.0f; // 10 mins
    }

    return _MSGCSessionedMobileConfigGetDouble(context, config, arg3, arg4);
}

#pragma mark - Hide floating Meta AI button

%hook MSGMetaAIFloatingActionButtonViewController

- (void)viewDidLoad {
    if (hideMetaAIFloatingButton) {
        [[self view] setHidden:YES];
        return;
    }

    %orig;
}

%end

#pragma mark - Hide notes row | Hide search bar

%hook MSGThreadListDataSource

- (instancetype)initWithViewRendererContext:(id)context mailbox:(id)mailbox config:(MSGThreadListConfig *)config {
    [config setValueForField:@"shouldShowSearch", !hideSearchBar];
    [config setValueForField:@"shouldShowInboxUnit", !hideNotesRow];
    return %orig;
}

%end

#pragma mark - Hide notification badges in chat top bar | Keyboard state after entering chat | Disable long press to change theme

%hook MSGThreadViewController

- (instancetype)initWithMailbox:(id)arg1 threadQueryKey:(id)arg2 threadSessionLifecycle:(id)arg3 threadNavigationData:(id)arg4 navigationEntryPoint:(int)arg5 options:(MSGThreadViewControllerOptions *)options metricContextsContainer:(id)arg7 datasource:(id)arg8 {
    MSGThreadViewOptions *viewOptions = [options viewOptions];

    [viewOptions setValueForField:@"shouldHideBadgeInBackButton", hideNotifBadgesInChat];

    if (![keyboardStateAfterEnterChat isEqual:@"ADAPTIVE"]) {
        [viewOptions setValueForField:@"onOpenKeyboardState", [keyboardStateAfterEnterChat isEqual:@"ALWAYS_EXPANDED"] ? 2 : 1];
    }

    return %orig;
}

- (void)messageListViewControllerDidLongPressBackground:(id)arg1 {
    if (!disableLongPressToChangeChatTheme) %orig;
}

%end

#pragma mark - Hide status bar when viewing story (iOS 12 devices only)

%hook LSMediaViewerViewController

- (BOOL)prefersStatusBarHidden {
    BOOL isCorrectController = [MSHookIvar<id>(self, "_contentController") isKindOfClass:%c(LSStoryViewerContentController)];
    return hideStatusBarWhenViewingStory && isCorrectController ? YES : %orig;
}

%end

#pragma mark - Hide suggested suggestions in search

%hook MSGUniversalSearchNullStateViewController

- (void)_updateHeaderList:(id)list {
    if (!hideSuggestionsInSearch) %orig;
}

%end

%hook LSContactListViewController

- (void)didLoadContactList:(NSArray *)list contactExtrasById:(NSDictionary *)extras {
    if (hideSuggestionsInSearch) {
        NSString *featureIdentifier = MSHookIvar<NSString *>(self, "_featureIdentifier");
        if ([featureIdentifier isEqual:@"universal_search_null_state"]) {
            return %orig(nil, nil);
        }
    }

    %orig;
}

%end

#pragma mark - Hide tabs in tab bar

static BOOL hideTabBar = NO;

%hook LSTabBarDataSource

- (instancetype)initWithDependencies:(id)dependencies inboxLoadedCompletion:(id)completion {
    LSTabBarDataSource *data = %orig;
    NSMutableArray *items = [MSHookIvar<NSArray *>(data, "_tabBarItems") mutableCopy];
    NSMutableArray *itemsInfo = [MSHookIvar<NSArray <MSGTabBarItemInfo *> *>(data, "_tabBarItemInfos") mutableCopy];
    NSArray *removedItems = @[hidePeopleTab ? @"tabbar-people" : @"", hideStoriesTab ? @"tabbar-stories" : @""];

    for (MSGTabBarItemInfo *info in [itemsInfo reverseObjectEnumerator]) {
        if ([removedItems containsObject:[[info props] accessibilityIdentifierText]]) {
            if ([itemsInfo count] > 2) {
                [itemsInfo removeObject:info];
                [items removeObject:info];
            } else {
                hideTabBar = YES;
                break;
            }
        }
    }

    [data setValue:itemsInfo forKey:@"_tabBarItemInfos"];
    [data setValue:items forKey:@"_tabBarItems"];
    return data;
}

%end

%hook MDSTabBarController

- (void)_prepareTabBar {
    if (!hideTabBar) %orig;
}

%end

#pragma mark - Hide typing indicator

%hook MSGThreadRowCell

- (BOOL)_isTypingWithModel:(id)arg1 {
    return [@[@"IN_THREAD_LIST_ONLY", @"BOTH"] containsObject:hideTypingIndicator] ? NO : %orig;
}

// v458.0.0
- (BOOL)_isTypingWithModel:(id)arg1 mailbox:(id)arg2 {
    return [@[@"IN_THREAD_LIST_ONLY", @"BOTH"] containsObject:hideTypingIndicator] ? NO : %orig;
}

%end

%hook MSGMessageListViewModelGenerator

- (void)didLoadThreadModel:(id)arg1 threadViewModelMap:(id)arg2 threadSessionIdentifier:(id)arg3 messageModels:(NSMutableArray <MSGTempMessageListItemModel *> *)models threadParticipants:(id)arg6 attributionIDV2:(id)arg7 loadMoreStateOlder:(int)arg8 loadMoreStateNewer:(int)arg9 didLoadNewIsland:(BOOL)arg10 modelFetchedTimeInSeconds:(CGFloat)arg11 completion:(id)arg12 {
    if ([models count] > 0) {
        MSGTempMessageListItemModel *indicatorModel = [models objectAtIndex:[models count] - 1];
        if ([@[@"IN_CHAT_ONLY", @"BOTH"] containsObject:hideTypingIndicator] && [[indicatorModel messageId] isEqual:@"typing_indicator"]) {
            [models removeObject:indicatorModel];
        }
    }

    %orig;
}

// v458.0.0
- (void)didLoadThreadModel:(id)arg1 threadViewModelMap:(id)arg2 threadSessionIdentifier:(id)arg3 messageModels:(NSMutableArray <MSGTempMessageListItemModel *> *)models threadParticipants:(id)arg5 attributionIDV2:(id)arg6 loadMoreStateOlder:(int)arg7 loadMoreStateNewer:(int)arg8 didLoadNewIsland:(BOOL)arg9 completion:(id)arg10 {
    if ([@[@"IN_CHAT_ONLY", @"BOTH"] containsObject:hideTypingIndicator] && [[[models lastObject] messageId] isEqual:@"typing_indicator"]) {
        [models removeLastObject];
    }

    %orig;
}

%end

#pragma mark - Remove ads

%hook MSGInboxAdsUserScopedPlugin

- (id)MSGInboxAdsUnitFetcher_MSGFetchInboxUnit:(id)arg1 {
    return noAds ? nil : %orig;
}

%end

// v458.0.0
%hook MSGThreadListDataSource

- (NSArray *)inboxRows {
    // Kept out of the message send: current Logos mis-expands %orig as a
    // message receiver here and drops the rest of the expression.
    NSArray *originalRows = %orig;
    NSMutableArray *currentRows = [originalRows mutableCopy];
    if ([self isInitializationComplete] && noAds && [currentRows count] > 0) {
        MSGThreadListUnitsSate *unitsState = MSHookIvar<MSGThreadListUnitsSate *>(self, "_unitsState");
        NSMutableDictionary *units = [unitsState unitKeyToUnit];
        MSGInboxUnit *adUnit = [units objectForKey:@"ads_renderer"];
        NSUInteger adUnitIndex = [[adUnit positionInThreadList] belowThreadIndex] + 2;
        BOOL isOffline = [units objectForKey:@"qp"];

        if (adUnit && adUnitIndex + isOffline < [currentRows count]) {
            [currentRows removeObjectAtIndex:adUnitIndex + isOffline];
        }
    }

    return currentRows;
}

%end

%hook LSStoryViewerContentController

- (void)_updateStoriesWithBucketStoryModels:(NSMutableArray *)models deletedIndexPaths:(id)arg2 addedIndexPaths:(NSArray *)addedIndexPaths newIndexPath:(id)arg4 {
    // Bucket types: 0 = unread | 1 = advertisement | 2 = read
    for (MSGStoryViewerBucketModel *model in [models reverseObjectEnumerator]) {
        if ([model bucketType] == 1) {
            [models removeObject:model];
            addedIndexPaths = @[];
        }
    }

    %orig;
}

%end

#pragma mark - Save friends' stories

%hook LSStoryOverlayProfileView

- (void)_handleOverflowMenuButton:(UIButton *)button {
    NSMutableArray *actions = [MSHookIvar<NSArray *>(self, "_overflowActions") mutableCopy];
    NSString *storyAuthorId = MSHookIvar<NSString *>(self, "_storyAuthorId");
    if (canSaveFriendsStories && ![storyAuthorId isEqual:[[%c(FBAnalytics) sharedAnalytics] userFBID]] && [actions count] == 3) {
        actionTypeSaveClass = MSGModelDefineClass(&actionTypeSaveInfo);
        MSGStoryViewerOverflowMenuActionTypeSave *actionTypeSave = nil;
        MSGStoryOverlayProfileViewActionStandard *actionStandard = nil;

        if (SNTraits().usesADTInfoInitialiser) {
            actionTypeSave = [actionTypeSaveClass newADTModelWithInfo:&actionTypeSaveInfo adtInfo:&actionTypeSaveADTInfo];
            actionStandard = [actionStandardClass newADTModelWithInfo:&actionStandardInfo adtInfo:&actionStandardADTInfo];
        } else {
            actionTypeSave = [actionTypeSaveClass newADTModelWithInfo:&actionTypeSaveInfo adtValueSubtype:actionTypeSaveADTInfo.subtype];
            actionStandard = [actionStandardClass newADTModelWithInfo:&actionStandardInfo adtValueSubtype:actionStandardADTInfo.subtype];
        }

        [actionStandard setValueForField:@"type", actionTypeSave];
        [actions insertObject:actionStandard atIndex:2];
        [self setValue:actions forKey:@"_overflowActions"];
    }

    %orig;
}

%end

// Diagnostic build only: record distinct navigation routes in Messenger. The
// recorder is bounded and only writes after a new route is observed.
%hook UIViewController

- (void)viewDidAppear:(BOOL)animated {
    %orig;
    SNDiagnosticsRecordViewController(self);
    SNInstallSettingsButtonIfNeeded(self);
}

%new(v@:@)
- (void)snmessenger_openTweakSettings:(id)sender {
    (void)sender;
    UINavigationController *navigationController = self.navigationController;
    if (navigationController == nil) return;

    isDarkMode = self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
    SNSettingsViewController *settingsController = [[SNSettingsViewController alloc] init];
    [navigationController pushViewController:settingsController animated:YES];
}

%end

%ctor {
    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, (CFNotificationCallback)reloadPrefs, CFSTR(PREF_CHANGED_NOTIF), NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
    reloadPrefs();

    tweakBundle = SNMessengerBundle();
    SNDiagnosticsStart();

    SNHookFunctions({
        {"LightSpeedCore", {
            {"LSRTCValidateCallIntentForKey", (void *)LSRTCValidateCallIntentForKey, (void **)&_LSRTCValidateCallIntentForKey},
            {"MDSColorTypeMdsColorCreate", NULL, (void **)&_MDSColorTypeMdsColorCreate},
            {"MDSGeneratedImageIconStyleNormalCreate", NULL, (void **)&_MDSGeneratedImageIconStyleNormalCreate},
            {"MDSGeneratedImageSpecIconCreate", NULL, (void **)&_MDSGeneratedImageSpecIconCreate}
        }}
    });

    if (SNTraits().lightSpeedSymbolsInEngine) {
        SNHookFunctions({
            {"LightSpeedEngine", {
                {"MSGModelDefineClass", (void *)MSGModelDefineClass, (void **)&_MSGModelDefineClass},
                {"MCQSHIMTransportHybridThreadMarkThreadRead", (void *)MCQSHIMTransportHybridThreadMarkThreadRead, (void **)&_MCQSHIMTransportHybridThreadMarkThreadRead},
                {"MCQTamClientTypingIndicatorStart", (void *)MCQTamClientTypingIndicatorStart, (void **)&_MCQTamClientTypingIndicatorStart},
                {"MSGAVFoundationEstimateMaxVideoDurationInputCreate", (void *)MSGAVFoundationEstimateMaxVideoDurationInputCreate, (void **)&_MSGAVFoundationEstimateMaxVideoDurationInputCreate}
            }}
        });
    } else {
        SNHookFunctions({
            {"LightSpeedCore", {
                {"MSGModelDefineClass", (void *)MSGModelDefineClass, (void **)&_MSGModelDefineClass},
                {"MCINotificationCenterPostStrictNotification", (void *)MCINotificationCenterPostStrictNotification, (void **)&_MCINotificationCenterPostStrictNotification},
                {"MSGCSessionedMobileConfigGetBoolean", (void *)MSGCSessionedMobileConfigGetBoolean, (void **)&_MSGCSessionedMobileConfigGetBoolean},
                {"MSGCSessionedMobileConfigGetDouble", (void *)MSGCSessionedMobileConfigGetDouble, (void **)&_MSGCSessionedMobileConfigGetDouble}
            }}
        });
    }

    %init(MSGMetaAIFloatingActionButtonViewController = objc_lookUpClass("MSGMetaAIFAB.MSGMetaAIFABViewController"));
}
