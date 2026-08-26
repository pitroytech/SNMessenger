#import "SNTableViewCell.h"

@implementation SNTableViewCell

- (instancetype)initWithData:(SNCellModel *)cellData reuseIdentifier:(NSString *)reuseIdentifier {
    if (self = [super initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:reuseIdentifier]) {
        _cellData = cellData;

        self.textLabel.adjustsFontSizeToFitWidth = YES;
        self.textLabel.text = localizedStringForKey(cellData.labelKey);
        self.textLabel.textColor = colorWithHexString(isDarkMode ? @"#F2F2F2" : @"#333333");

        self.detailTextLabel.text = localizedStringForKey(_cellData.subtitleKey);
        self.detailTextLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightRegular];
        self.detailTextLabel.textColor = colorWithHexString(isDarkMode ? @"#888888" : @"#828282");

        self.imageView.image = scaleImageWithSize(cellData.image, CGSizeMake(42, 42));
        self.imageView.layer.cornerRadius = 21.0f;
        self.imageView.clipsToBounds = YES;

        if (cellData.disabled) {
            self.userInteractionEnabled = NO;
            self.textLabel.enabled = NO;
        }

        switch (cellData.type) {
            case Button: {
                self.accessoryView = MDSGeneratedImageViewCreate(@"ChevronRight", 10094, {24, 24});
                break;
            }

            case Switch: {
                [self loadSwitcher];
                break;
            }

            case Link: {
                self.accessoryType = UITableViewCellAccessoryNone;
                break;
            }

            case Option: {
                [self loadOption];
                break;
            }

            default:
                break;
        }
    }

    return self;
}

- (void)prepareForReuse {
    [super prepareForReuse];
    switch (_cellData.type) {
        case Switch: {
            [self loadSwitcher];
            break;
        }

        case Option: {
            [self loadOption];
            break;
        }

        default:
            break;
    }
}

- (void)setSeparatorColor:(UIColor *)separatorColor {
    [super setSeparatorColor:colorWithHexString(isDarkMode ? @"#FFFFFF30" : @"#0000001E")];
}

- (void)setHighlighted:(BOOL)highlighted animated:(BOOL)animated {
    [super setHighlighted:highlighted animated:animated];
    if (highlighted) {
        self.contentView.superview.backgroundColor = colorWithHexString(isDarkMode ? @"#FFFFFF23" : @"#0000000F");
    } else {
        self.contentView.superview.backgroundColor = colorWithHexString(isDarkMode ? @"#FFFFFF14" : @"#FFFFFF");
    }
}

- (void)loadOption {
    id savedValue = [self readPreferenceValueForKey:_cellData.prefKey];
    NSString *value = savedValue ?: _cellData.defaultValue;

    MDSGeneratedImageView *indicatorView = MDSGeneratedImageViewCreate(@"Checkmark", 10096, {24, 24});
    self.accessoryView = [value isEqualToString:_cellData.labelKey] ? indicatorView : nil;
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
    if (_cellData.type == Option && selected) {
        [self setPreferenceValue:_cellData.labelKey];
    }
}

- (void)loadSwitcher {
    id savedValue = [self readPreferenceValueForKey:_cellData.prefKey];
    BOOL value = [savedValue ?: _cellData.defaultValue boolValue];

    UISwitch *switchView = [[UISwitch alloc] init];
    [switchView setOn:value animated:NO];
    [switchView addTarget:self action:@selector(switchChanged:) forControlEvents:UIControlEventValueChanged];
    if (_cellData.disabled) switchView.enabled = NO;
    self.accessoryView = switchView;
}

- (void)switchChanged:(UISwitch *)switchControl {
    [self setPreferenceValue:@([switchControl isOn])];
}

- (void)setPreferenceValue:(id)value {
    setCurrentPreferenceValue(value, _cellData.prefKey);
}

- (id)readPreferenceValueForKey:(NSString *)prefKey {
    return getCurrentSettings()[prefKey];
}

@end
