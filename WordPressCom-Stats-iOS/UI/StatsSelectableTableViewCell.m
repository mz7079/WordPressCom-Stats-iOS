#import "StatsSelectableTableViewCell.h"
#import <WordPress-iOS-Shared/UIImage+Util.h>
#import "WPStyleGuide+Stats.h"
#import "StatsBorderedCellBackgroundView.h"

@interface StatsSelectableTableViewCell ()

@property (nonatomic, weak) IBOutlet UIImageView *categoryIcon;
@property (nonatomic, weak) IBOutlet UILabel *categoryLabel;

@property (nonatomic, strong) UIView *sideBorderView;
@property (nonatomic, strong) UIView *darkerBackgroundView;
@property (nonatomic, strong) UIView *lighterBackgroundView;

@end

@implementation StatsSelectableTableViewCell

- (void)awakeFromNib {
    [super awakeFromNib];
    
    self.selectedIsLighter = YES;
    self.cellType = StatsSelectableTableViewCellTypeViews;
    [self updateLabels];
    
    // Standard colors for use in the graph view
    self.selectedCellTextColor = [WPStyleGuide statsDarkGray];
    self.selectedCellValueColor = [WPStyleGuide jazzyOrange];
    self.selectedCellValueZeroColor = [WPStyleGuide jazzyOrange];
    self.unselectedCellTextColor = [WPStyleGuide statsLessDarkGrey];
    self.unselectedCellValueColor = [WPStyleGuide littleEddieGrey];
    self.unselectedCellValueZeroColor = [WPStyleGuide statsLightGrayZeroValue];
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    self.backgroundView.frame = self.bounds;
    self.selectedBackgroundView.frame = self.bounds;
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
    [super setSelected:selected animated:animated];

    if (selected) {
        self.categoryIcon.tintColor = self.selectedCellTextColor;
        self.categoryLabel.textColor = self.selectedCellTextColor;
        self.valueLabel.textColor = self.selectedCellValueColor;
    } else {
        self.categoryIcon.tintColor = self.unselectedCellTextColor;
        self.categoryLabel.textColor = self.unselectedCellTextColor;
        
        if ([self.valueLabel.text isEqualToString:@"0"]) {
            self.valueLabel.textColor = self.unselectedCellValueZeroColor;
        } else {
            self.valueLabel.textColor = self.unselectedCellValueColor;
        }
    }
}

- (void)setSelectedIsLighter:(BOOL)selectedIsLighter
{
    _selectedIsLighter = selectedIsLighter;
    
    if (selectedIsLighter) {
        self.backgroundView = [[StatsBorderedCellBackgroundView alloc] initWithFrame:self.bounds andSelected:NO];
        self.selectedBackgroundView = [[StatsBorderedCellBackgroundView alloc] initWithFrame:self.bounds andSelected:YES];
    } else {
        self.backgroundView = [[StatsBorderedCellBackgroundView alloc] initWithFrame:self.bounds andSelected:YES];
        self.selectedBackgroundView = [[StatsBorderedCellBackgroundView alloc] initWithFrame:self.bounds andSelected:NO];
    }
}

- (void)prepareForReuse
{
    [super prepareForReuse];
    
    self.selectedIsLighter = NO;
    self.cellType = StatsSelectableTableViewCellTypeViews;
}

- (void)setCellType:(StatsSelectableTableViewCellType)cellType
{
    if (cellType == _cellType) {
        return;
    }
    
    _cellType = cellType;
    [self updateLabels];
}

- (void)updateLabels
{
    switch (self.cellType) {
        case StatsSelectableTableViewCellTypeViews:
        {
            self.categoryIcon.image = [[UIImage imageNamed:@"icon-eye-25x25" inBundle:self.bundle compatibleWithTraitCollection:nil] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
            self.categoryLabel.text = [NSLocalizedString(@"Views", @"") uppercaseStringWithLocale:[NSLocale currentLocale]];
            break;
        }
            
        case StatsSelectableTableViewCellTypeVisitors:
        {
            self.categoryIcon.image = [[UIImage imageNamed:@"icon-user-25x25" inBundle:self.bundle compatibleWithTraitCollection:nil] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
            self.categoryLabel.text = [NSLocalizedString(@"Visitors", @"") uppercaseStringWithLocale:[NSLocale currentLocale]];
            break;
        }
            
        case StatsSelectableTableViewCellTypeLikes:
        {
            self.categoryIcon.image = [[UIImage imageNamed:@"icon-star-25x25" inBundle:self.bundle compatibleWithTraitCollection:nil] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
            self.categoryLabel.text = [NSLocalizedString(@"Likes", @"") uppercaseStringWithLocale:[NSLocale currentLocale]];
            break;
        }
            
        case StatsSelectableTableViewCellTypeComments:
        {
            self.categoryIcon.image = [[UIImage imageNamed:@"icon-comment-25x25" inBundle:self.bundle compatibleWithTraitCollection:nil] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
            self.categoryLabel.text = [NSLocalizedString(@"Comments", @"") uppercaseStringWithLocale:[NSLocale currentLocale]];
            break;
        }
            
        default:
            break;
    }
}

- (NSBundle *)bundle
{
    NSString *path = [[NSBundle mainBundle] pathForResource:@"WordPressCom-Stats-iOS" ofType:@"bundle"];
    NSBundle *bundle = [NSBundle bundleWithPath:path];
    
    return bundle;
}


@end
