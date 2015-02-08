#import "StatsStandardBorderedTableViewCell.h"
#import "WPStyleGuide+Stats.h"
#import "StatsBorderedCellBackgroundView.h"

@implementation StatsStandardBorderedTableViewCell

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    self.backgroundView.frame = self.bounds;
    self.selectedBackgroundView.frame = self.bounds;
}


- (void)awakeFromNib
{
    [super awakeFromNib];
    
    _bottomBorderEnabled = YES;
    self.backgroundView = [[StatsBorderedCellBackgroundView alloc] initWithFrame:self.bounds andSelected:YES];
    self.selectedBackgroundView = [[StatsBorderedCellBackgroundView alloc] initWithFrame:self.bounds andSelected:NO];
}


- (void)setBottomBorderEnabled:(BOOL)bottomBorderEnabled
{
    _bottomBorderEnabled = bottomBorderEnabled;
    
    StatsBorderedCellBackgroundView *backgroundView = (StatsBorderedCellBackgroundView *)self.backgroundView;
    StatsBorderedCellBackgroundView *selectedBackgroundView = (StatsBorderedCellBackgroundView *)self.selectedBackgroundView;
    backgroundView.bottomBorderEnabled = bottomBorderEnabled;
    selectedBackgroundView.bottomBorderEnabled = bottomBorderEnabled;
}

@end