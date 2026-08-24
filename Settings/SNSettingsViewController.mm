#import "SNSettingsViewController.h"
#import "SNSubSettingsViewController.h"
#import <signal.h>

@implementation SNSettingsViewController

- (instancetype)init {
    if (self = [super init]) {
        self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:localizedStringForKey(@"APPLY") style:UIBarButtonItemStyleDone target:self action:@selector(close)];

        self.navigationItem.titleView = [[UIView alloc] init];
        UILabel *titleLabel = [[UILabel alloc] init];
        titleLabel.font = [UIFont systemFontOfSize:17.5f weight:UIFontWeightBold];
        titleLabel.text = localizedStringForKey(@"ADVANCED_SETTINGS");
        titleLabel.textAlignment = NSTextAlignmentCenter;
        titleLabel.textColor = isDarkMode ? [UIColor whiteColor] : [UIColor blackColor];
        titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
        [self.navigationItem.titleView addSubview:titleLabel];

        [NSLayoutConstraint activateConstraints:@[
            [titleLabel.topAnchor constraintEqualToAnchor:self.navigationItem.titleView.topAnchor],
            [titleLabel.leadingAnchor constraintEqualToAnchor:self.navigationItem.titleView.leadingAnchor],
            [titleLabel.trailingAnchor constraintEqualToAnchor:self.navigationItem.titleView.trailingAnchor],
            [titleLabel.bottomAnchor constraintEqualToAnchor:self.navigationItem.titleView.bottomAnchor],
        ]];
    }

    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    // Set original settings so we can deal with changes later
    _originalSettings = getCurrentSettings();

    // Init table view
    _tableView = [[TOInsetGroupedTableView alloc] initWithFrame:[self.view frame]];
    _tableView.delegate = self;
    _tableView.dataSource = self;
    [self.view addSubview:_tableView];

    [self initSettingsData];
}

- (void)initSettingsData {
    //======================== GENERAL OPTIONS =========================//

    SNCellModel *noAdsCell = [[SNCellModel alloc] initWithType:Switch labelKey:@"NO_ADS"];
    noAdsCell.subtitleKey = @"NO_ADS_DESCRIPTION";
    noAdsCell.prefKey = @"noAds";
    noAdsCell.defaultValue = @(YES);

    SNCellModel *showTheEyeCell = [[SNCellModel alloc] initWithType:Switch labelKey:@"SHOW_THE_EYE_BUTTON"];
    showTheEyeCell.subtitleKey = @"QUICK_ENABLE_DISABLE_READ_RECEIPT";
    showTheEyeCell.prefKey = @"showTheEyeButton";
    showTheEyeCell.isRestartRequired = YES;
    showTheEyeCell.defaultValue = @(YES);

    //========================== CHAT OPTIONS ==========================//

    SNCellModel *alwaysSendHdPhotosCell = [[SNCellModel alloc] initWithType:Switch labelKey:@"ALWAYS_SEND_HD_PHOTOS"];
    alwaysSendHdPhotosCell.subtitleKey = @"ALWAYS_SEND_HD_PHOTOS_DESCRIPTION";
    alwaysSendHdPhotosCell.prefKey = @"alwaysSendHdPhotos";
    alwaysSendHdPhotosCell.defaultValue = @(YES);

    SNCellModel *callConfirmationCell = [[SNCellModel alloc] initWithType:Switch labelKey:@"CALL_CONFIRMATION"];
    callConfirmationCell.prefKey = @"callConfirmation";
    callConfirmationCell.defaultValue = @(YES);

    SNCellModel *configKeyboardState = [[SNCellModel alloc] initWithType:Button labelKey:@"CONFIG_KEYBOARD_STATE"];
    configKeyboardState.actionBlock = ^{ [self openSubSettingsWithIdentifier:@"Keyboard-State"]; };

    SNCellModel *configTypingIndicatorCell = [[SNCellModel alloc] initWithType:Button labelKey:@"CONFIG_TYPING_INDICATOR"];
    configTypingIndicatorCell.actionBlock = ^{ [self openSubSettingsWithIdentifier:@"Typing-Indicator"]; };

    SNCellModel *disableLongPressToChangeThemeCell = [[SNCellModel alloc] initWithType:Switch labelKey:@"DISABLE_LONG_PRESS_TO_CHANGE_THEME"];
    disableLongPressToChangeThemeCell.prefKey = @"disableLongPressToChangeTheme";

    SNCellModel *disableReadReceiptsCell = [[SNCellModel alloc] initWithType:Switch labelKey:@"DISABLE_READ_RECEIPTS"];
    disableReadReceiptsCell.subtitleKey = @"DISABLE_READ_RECEIPTS_DESCRIPTION";
    disableReadReceiptsCell.prefKey = @"disableReadReceipts";
    disableReadReceiptsCell.defaultValue = @(YES);

    SNCellModel *hideNotifBadgesInChatCell = [[SNCellModel alloc] initWithType:Switch labelKey:@"HIDE_NOTIF_BADGES_IN_CHAT"];
    hideNotifBadgesInChatCell.prefKey = @"hideNotifBadgesInChat";

    //========================= STORY OPTIONS ==========================//

    SNCellModel *canSaveFriendsStoriesCell = [[SNCellModel alloc] initWithType:Switch labelKey:@"CAN_SAVE_FRIENDS_STORIES"];
    canSaveFriendsStoriesCell.prefKey = @"canSaveFriendsStories";
    canSaveFriendsStoriesCell.defaultValue = @(YES);

    SNCellModel *disableStoriesPreviewCell = [[SNCellModel alloc] initWithType:Switch labelKey:@"DISABLE_STORIES_PREVIEW"];
    disableStoriesPreviewCell.prefKey = @"disableStoriesPreview";
    disableStoriesPreviewCell.isRestartRequired = YES;

    SNCellModel *disableStorySeenReceiptsCell = [[SNCellModel alloc] initWithType:Switch labelKey:@"DISABLE_STORY_SEEN_RECEIPTS"];
    disableStorySeenReceiptsCell.prefKey = @"disableStorySeenReceipts";
    disableStorySeenReceiptsCell.defaultValue = @(YES);

    SNCellModel *extendStoryVideoUploadLengthCell = [[SNCellModel alloc] initWithType:Switch labelKey:@"EXTEND_STORY_VIDEO_UPLOAD_LENGTH"];
    extendStoryVideoUploadLengthCell.subtitleKey = @"EXTEND_STORY_VIDEO_UPLOAD_LENGTH_DESCRIPTION";
    extendStoryVideoUploadLengthCell.prefKey = @"extendStoryVideoUploadLength";
    extendStoryVideoUploadLengthCell.defaultValue = @(YES);

    SNCellModel *hideStatusBarWhenViewingStoryCell = [[SNCellModel alloc] initWithType:Switch labelKey:@"HIDE_STATUS_BAR_WHEN_VIEWING_STORY"];
    hideStatusBarWhenViewingStoryCell.subtitleKey = @"HIDE_STATUS_BAR_WHEN_VIEWING_STORY_DESCRIPTION";
    hideStatusBarWhenViewingStoryCell.prefKey = @"hideStatusBarWhenViewingStory";
    hideStatusBarWhenViewingStoryCell.disabled = IS_IOS_OR_NEWER(iOS_13_0);

    SNCellModel *neverReplayStoryAfterReactingCell = [[SNCellModel alloc] initWithType:Switch labelKey:@"NEVER_REPLAY_STORY_AFTER_REACTING"];
    neverReplayStoryAfterReactingCell.prefKey = @"neverReplayStoryAfterReacting";

    //=========================== UI OPTIONS ===========================//

    SNCellModel *hideMetaAIFloatingButtonCell = [[SNCellModel alloc] initWithType:Switch labelKey:@"HIDE_META_AI_FLOATING_BUTTON"];
    hideMetaAIFloatingButtonCell.prefKey = @"hideMetaAIFloatingButton";
    hideMetaAIFloatingButtonCell.isRestartRequired = YES;

    SNCellModel *hidePeopleTabCell = [[SNCellModel alloc] initWithType:Switch labelKey:@"HIDE_PEOPLE_TAB"];
    hidePeopleTabCell.prefKey = @"hidePeopleTab";
    hidePeopleTabCell.isRestartRequired = YES;
    hidePeopleTabCell.disabled = SNTraits().lightSpeedSymbolsInEngine;

    SNCellModel *hideStoriesTabCell = [[SNCellModel alloc] initWithType:Switch labelKey:@"HIDE_STORIES_TAB"];
    hideStoriesTabCell.prefKey = @"hideStoriesTab";
    hideStoriesTabCell.isRestartRequired = YES;

    SNCellModel *hideNotesRowCell = [[SNCellModel alloc] initWithType:Switch labelKey:@"HIDE_NOTES_ROW"];
    hideNotesRowCell.prefKey = @"hideNotesRow";
    hideNotesRowCell.isRestartRequired = YES;

    SNCellModel *hideSearchBarCell = [[SNCellModel alloc] initWithType:Switch labelKey:@"HIDE_SEARCH_BAR"];
    hideSearchBarCell.prefKey = @"hideSearchBar";
    hideSearchBarCell.isRestartRequired = YES;

    SNCellModel *hideSuggestionsInSearchCell = [[SNCellModel alloc] initWithType:Switch labelKey:@"HIDE_SUGGESTIONS_IN_SEARCH"];
    hideSuggestionsInSearchCell.prefKey = @"hideSuggestionsInSearch";

    //=========================== SUPPORT ME ===========================//

    SNCellModel *authorCell = [[SNCellModel alloc] initWithType:Link labelKey:@"Nguyễn Anh Sáng"];
    authorCell.url = @"https://github.com/NguyenASang";
    authorCell.subtitleKey = @"AUTHOR_DESCRIPTION";
    authorCell.image = getImage(@"Author");

    SNCellModel *supporterCell = [[SNCellModel alloc] initWithType:Link labelKey:@"Thatchapon Unprasert"];
    supporterCell.url = @"https://github.com/PoomSmart";
    supporterCell.subtitleKey = @"SUPPORTER_DESCRIPTION";
    supporterCell.image = getImage(@"Supporter");

    SNCellModel *sourceCodeCell = [[SNCellModel alloc] initWithType:Link labelKey:@"SOURCE_CODE"];
    sourceCodeCell.url = @"https://github.com/NguyenASang/SNMessenger";
    sourceCodeCell.subtitleKey = @"Github";
    sourceCodeCell.image = getImage(@"GitHub");

    SNCellModel *donationCell = [[SNCellModel alloc] initWithType:Link labelKey:@"DONATION"];
    donationCell.url = @"https://paypal.me/nguyensang15";
    donationCell.subtitleKey = @"BUY_ME_A_COFFEE";
    donationCell.image = getImage(@"PayPal");

    _tableData = @{
        @"0": @[
                noAdsCell,
                showTheEyeCell
            ],

        @"1": @[
                alwaysSendHdPhotosCell,
                callConfirmationCell,
                configKeyboardState,
                configTypingIndicatorCell,
                disableLongPressToChangeThemeCell,
                disableReadReceiptsCell,
                hideNotifBadgesInChatCell
            ],

        @"2": @[
                canSaveFriendsStoriesCell,
                disableStoriesPreviewCell,
                disableStorySeenReceiptsCell,
                extendStoryVideoUploadLengthCell,
                hideStatusBarWhenViewingStoryCell,
                neverReplayStoryAfterReactingCell
            ],

        @"3": @[
                hideMetaAIFloatingButtonCell,
                hideNotesRowCell,
                hidePeopleTabCell,
                hideStoriesTabCell,
                hideSearchBarCell,
                hideSuggestionsInSearchCell
            ],

        @"4": @[
                authorCell,
                supporterCell,
                sourceCodeCell,
                donationCell
            ]
    };
}

- (NSInteger)numberOfSectionsInTableView:(TOInsetGroupedTableView *)tableView {
    return [_tableData count];
}

- (NSInteger)tableView:(TOInsetGroupedTableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [[_tableData valueForKey:[@(section) stringValue]] count];
}

- (NSString *)tableView:(TOInsetGroupedTableView *)tableView titleForHeaderInSection:(NSInteger)section {
    switch (section) {
        case 0:
            return localizedStringForKey(@"GENERAL_OPTIONS");
        case 1:
            return localizedStringForKey(@"CHAT_OPTIONS");
        case 2:
            return localizedStringForKey(@"STORY_OPTIONS");
        case 3:
            return localizedStringForKey(@"UI_OPTIONS");
        case 4:
            return localizedStringForKey(@"SUPPORT_ME");
        default:
            return nil;
    }
}

- (void)tableView:(TOInsetGroupedTableView *)tableView willDisplayHeaderView:(UIView *)view forSection:(NSInteger)section {
    if ([view isKindOfClass:[UITableViewHeaderFooterView class]]) {
        UITableViewHeaderFooterView *headerView = (UITableViewHeaderFooterView *)view;
        headerView.textLabel.text = [self tableView:tableView titleForHeaderInSection:section];
        headerView.textLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightSemibold];
    }
}

- (SNTableViewCell *)tableView:(TOInsetGroupedTableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSArray *rowData = [_tableData valueForKey:[@(indexPath.section) stringValue]];
    SNCellModel *cellData = [rowData objectAtIndex:indexPath.row];

    NSString *cellIdentifier = [NSString stringWithFormat:@"SNTableViewCell - type: %lu - labelKey: %@ - subtitleKey: %@", cellData.type, cellData.labelKey, cellData.subtitleKey];
    SNTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    if (cell == nil) {
        cell = [[SNTableViewCell alloc] initWithData:cellData reuseIdentifier:cellIdentifier];
    }

    return cell;
}

- (CGFloat)tableView:(TOInsetGroupedTableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSArray *rowData = [_tableData valueForKey:[@(indexPath.section) stringValue]];
    SNCellModel *cellData = [rowData objectAtIndex:indexPath.row];
    return cellData.subtitleKey ? 173.0f / 3.0f : 52.0f;
}

- (NSString *)tableView:(TOInsetGroupedTableView *)tableView titleForFooterInSection:(NSInteger)section {
    return section == [_tableData count] - 1 ? @"SNMessenger, fuck Meta 🔥" : nil;
}

- (void)tableView:(TOInsetGroupedTableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    NSArray *rowData = [_tableData valueForKey:[@(indexPath.section) stringValue]];
    SNCellModel *cellData = [rowData objectAtIndex:indexPath.row];
    if (cellData.type == Link) {
        UIApplication *app = [UIApplication sharedApplication];
        [app openURL:[NSURL URLWithString:cellData.url] options:@{} completionHandler:nil];
    }

    if (cellData.type == Button && cellData.actionBlock) {
        cellData.actionBlock();
    }

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.5 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        [tableView deselectRowAtIndexPath:indexPath animated:YES];
    });
}

- (void)openSubSettingsWithIdentifier:(NSString *)identifier {
    SNSubSettingsViewController *subSettings = [[SNSubSettingsViewController alloc] initWithIdentifier:identifier];
    [self.navigationController pushViewController:subSettings animated:YES];
}

- (void)showRequireRestartAlert {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:localizedStringForKey(@"RESTART_MESSAGE") message:localizedStringForKey(@"RESTART_CONFIRM_MESSAGE") preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:localizedStringForKey(@"CONFIRM") style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
        abort();
    }]];

    [alert addAction:[UIAlertAction actionWithTitle:localizedStringForKey(@"CANCEL") style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {
        [self dismissViewControllerAnimated:YES completion:nil];
    }]];

    [self presentViewController:alert animated:YES completion:nil];
}

- (void)close {
    NSDictionary *diffs = compareDictionaries(_originalSettings, getCurrentSettings());
    NSArray *diffKeys = [diffs allKeys];
    NSArray *tableValues = [_tableData allValues];

    for (NSArray *modelsArray in tableValues) {
        for (SNCellModel *model in modelsArray) {
            if ([diffKeys containsObject:model.prefKey] && model.isRestartRequired) {
                [self showRequireRestartAlert];
                return;
            }
        }
    }

    if ([self.navigationController respondsToSelector:@selector(_handleEscapeKey)]) {
        [(MDSNavigationController *)self.navigationController _handleEscapeKey];
    } else {
        [self dismissViewControllerAnimated:YES completion:nil];
    }
}

@end
