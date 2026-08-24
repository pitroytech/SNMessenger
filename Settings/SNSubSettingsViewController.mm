#import "SNSubSettingsViewController.h"

@implementation SNSubSettingsViewController

- (instancetype)initWithIdentifier:(NSString *)identifier {
    if (self = [super init]) {
        self.navigationItem.titleView = [[UIView alloc] init];
        UILabel *titleLabel = [[UILabel alloc] init];
        titleLabel.font = [UIFont systemFontOfSize:17 weight:UIFontWeightSemibold];
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

        SwitchStr (_identifier = identifier) {
            CaseEqual(@"Typing-Indicator") {
                titleLabel.text = localizedStringForKey(@"CONFIG_TYPING_INDICATOR_TITLE");
                break;
            }

            CaseEqual(@"Keyboard-State") {
                titleLabel.text = localizedStringForKey(@"CONFIG_KEYBOARD_STATE_TITLE");
                break;
            }

            Default {
                RLog(@"Unknown indentifier: %@", _identifier);
                break;
            }
        }
    }

    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    // Init table view
    _tableView = [[TOInsetGroupedTableView alloc] initWithFrame:[self.view frame]];
    _tableView.delegate = self;
    _tableView.dataSource = self;
    [self.view addSubview:_tableView];

    // Setup table rows
    SwitchStr (_identifier) {
        CaseEqual(@"Typing-Indicator") {
            [self initTypingIndicatorSettingsData];
            break;
        }

        CaseEqual(@"Keyboard-State") {
            [self initKeyboardStateSettingsData];
            break;
        }

        Default {
            RLog(@"Unknown indentifier: %@", _identifier);
            break;
        }
    }

}

- (void)initTypingIndicatorSettingsData {
    SNCellModel *disableTypingIndicatorCell = [[SNCellModel alloc] initWithType:Switch labelKey:@"DISABLE_TYPING_INDICATOR"];
    disableTypingIndicatorCell.subtitleKey = @"DISABLE_TYPING_INDICATOR_DESCRIPTION";
    disableTypingIndicatorCell.prefKey = @"disableTypingIndicator";
    disableTypingIndicatorCell.defaultValue = @(NO);
    disableTypingIndicatorCell.disabled = !SNTraits().lightSpeedSymbolsInEngine;

    SNCellModel *hideTypingIndicatorCell = [[SNCellModel alloc] initWithType:OptionsList labelKey:@"HIDE_TYPING_INDICATOR"];
    hideTypingIndicatorCell.prefKey = @"hideTypingIndicator";
    hideTypingIndicatorCell.options = @[@"NOWHERE", @"IN_CHAT_ONLY", @"IN_THREAD_LIST_ONLY", @"BOTH"];
    hideTypingIndicatorCell.defaultValue = @"NOWHERE";

    _headersList = @[@"", @"HIDE_TYPING_INDICATOR_HEADER_TITLE"];
    _tableData = @{
        @"0": @[disableTypingIndicatorCell],
        @"1": [hideTypingIndicatorCell getOptionsList]
    };
}

- (void)initKeyboardStateSettingsData {
    SNCellModel *keyboardStateAfterEnterChatCell = [[SNCellModel alloc] initWithType:OptionsList labelKey:@"KEYBOARD_STATE_AFTER_ENTER_CHAT"];
    keyboardStateAfterEnterChatCell.prefKey = @"keyboardStateAfterEnterChat";
    keyboardStateAfterEnterChatCell.titleKey = @"KEYBOARD_STATE_AFTER_ENTER_CHAT_TITLE";
    keyboardStateAfterEnterChatCell.options = @[@"ADAPTIVE", @"ALWAYS_EXPANDED", @"ALWAYS_COLLAPSED"];
    keyboardStateAfterEnterChatCell.defaultValue = @"ADAPTIVE";

    _headersList = @[@"KEYBOARD_STATE_AFTER_ENTER_CHAT"];
    _tableData = @{
        @"0": [keyboardStateAfterEnterChatCell getOptionsList]
    };
}

- (NSInteger)numberOfSectionsInTableView:(TOInsetGroupedTableView *)tableView {
    return [_tableData count];
}

- (NSInteger)tableView:(TOInsetGroupedTableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [[_tableData valueForKey:[@(section) stringValue]] count];
}

- (NSString *)tableView:(TOInsetGroupedTableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return localizedStringForKey([_headersList objectAtIndex:section]);
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
    [_tableView reloadData];
}

@end
