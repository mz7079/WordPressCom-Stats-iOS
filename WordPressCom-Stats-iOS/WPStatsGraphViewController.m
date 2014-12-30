#import "WPStatsGraphViewController.h"
#import "WPStatsGraphLegendView.h"
#import "WPStatsGraphBarCell.h"
#import <WPStyleGuide.h>
#import "WPStatsCollectionViewFlowLayout.h"
#import "WPStatsGraphBackgroundView.h"
#import "WPStyleGuide+Stats.h"

@interface WPStatsGraphViewController () <UICollectionViewDelegateFlowLayout>
{
    NSUInteger _selectedBarIndex;
}

@property (nonatomic, weak) WPStatsCollectionViewFlowLayout *flowLayout;
@property (nonatomic, assign) CGFloat maximumY;
@property (nonatomic, assign) NSUInteger numberOfXValues;
@property (nonatomic, assign) NSUInteger numberOfYValues;

@end

static NSString *const CategoryBarCell = @"CategoryBarCell";
static NSString *const LegendView = @"LegendView";
static NSString *const FooterView = @"FooterView";
static NSString *const GraphBackgroundView = @"GraphBackgroundView";
static NSInteger const RecommendedYAxisTicks = 7;

@implementation WPStatsGraphViewController

- (instancetype)init
{
    WPStatsCollectionViewFlowLayout *layout = [[WPStatsCollectionViewFlowLayout alloc] init];
    self = [super initWithCollectionViewLayout:layout];
    if (self) {
        _flowLayout = layout;
        _numberOfYValues = 7;
        _maximumY = 0;
        _allowDeselection = YES;
        _currentUnit = StatsPeriodUnitDay;
        _currentSummaryType = StatsSummaryTypeViews;
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.collectionView.backgroundColor = [UIColor lightGrayColor];
    
    self.flowLayout.scrollDirection = UICollectionViewScrollDirectionVertical;
    self.collectionView.allowsMultipleSelection = YES;
    self.collectionView.showsHorizontalScrollIndicator = NO;
    self.collectionView.showsVerticalScrollIndicator = NO;
    self.collectionView.scrollEnabled = NO;
    self.collectionView.contentInset = UIEdgeInsetsMake(0.0f, 40.0f, 0.0f, 15.0f);
    
    [self.collectionView registerClass:[WPStatsGraphBarCell class] forCellWithReuseIdentifier:CategoryBarCell];
    [self.collectionView registerClass:[UICollectionReusableView class] forSupplementaryViewOfKind:UICollectionElementKindSectionFooter withReuseIdentifier:FooterView];
    [self.collectionView registerClass:[WPStatsGraphBackgroundView class] forSupplementaryViewOfKind:WPStatsCollectionElementKindGraphBackground withReuseIdentifier:GraphBackgroundView];
    
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation
{
    [super didRotateFromInterfaceOrientation:fromInterfaceOrientation];
    
    [self.collectionView performBatchUpdates:nil completion:nil];
    
    if ([[self.collectionView indexPathsForSelectedItems] count] > 0) {
        NSIndexPath *indexPath = [self.collectionView indexPathsForSelectedItems][0];
        [self collectionView:self.collectionView didSelectItemAtIndexPath:indexPath];
    }
}

#pragma mark - UICollectionViewDelegate methods

- (BOOL)collectionView:(UICollectionView *)collectionView shouldDeselectItemAtIndexPath:(NSIndexPath *)indexPath
{
    return self.allowDeselection;
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath
{
    NSArray *selectedIndexPaths = [collectionView indexPathsForSelectedItems];
    [selectedIndexPaths enumerateObjectsUsingBlock:^(NSIndexPath *selectedIndexPath, NSUInteger idx, BOOL *stop) {
        if (!([selectedIndexPath compare:indexPath] == NSOrderedSame)) {
            [collectionView deselectItemAtIndexPath:selectedIndexPath animated:YES];
        }
    }];
    
    if ([self.graphDelegate respondsToSelector:@selector(statsGraphViewController:didSelectDate:)]) {
        StatsSummary *summary = (StatsSummary *)self.visits.statsData[indexPath.row];
        [self.graphDelegate statsGraphViewController:self didSelectDate:summary.date];
    }
}

- (void)collectionView:(UICollectionView *)collectionView didDeselectItemAtIndexPath:(NSIndexPath *)indexPath
{
    if ([[collectionView indexPathsForSelectedItems] count] == 0
        && [self.graphDelegate respondsToSelector:@selector(statsGraphViewControllerDidDeselectAllBars:)]) {
        [self.graphDelegate statsGraphViewControllerDidDeselectAllBars:self];
    }
}

#pragma mark - UICollectionViewDataSource methods

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
    return self.visits.statsData.count;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    WPStatsGraphBarCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:CategoryBarCell forIndexPath:indexPath];
    NSArray *barData = [self barDataForIndexPath:indexPath];
    
    cell.maximumY = self.maximumY;
    cell.numberOfYValues = self.numberOfYValues;
    
    [cell setCategoryBars:barData];
    cell.barName = [self.visits.statsData[indexPath.row] label];
    [cell finishedSettingProperties];
    
    return cell;
}

- (UICollectionReusableView *)collectionView:(UICollectionView *)collectionView viewForSupplementaryElementOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath
{
    if ([kind isEqualToString:WPStatsCollectionElementKindGraphBackground]) {
        WPStatsGraphBackgroundView *background = [collectionView dequeueReusableSupplementaryViewOfKind:kind withReuseIdentifier:GraphBackgroundView forIndexPath:indexPath];
        background.maximumYValue = self.maximumY;
        background.numberOfXValues = self.numberOfXValues;
        background.numberOfYValues = self.numberOfYValues;
        
        return background;
    }
    
    return nil;
}

#pragma mark - UICollectionViewDelegateFlowLayout methods

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout*)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath
{
    CGFloat width = 30.0f;
    CGFloat height = CGRectGetHeight(collectionView.frame);
    
    CGSize size = CGSizeMake(width, height);
    
    return size;
}

- (CGFloat)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout*)collectionViewLayout minimumInteritemSpacingForSectionAtIndex:(NSInteger)section
{
    CGFloat spacing = floorf((CGRectGetWidth(collectionView.frame) - 55 - (30.0 * self.numberOfXValues)) / self.numberOfXValues);
    
    return spacing;
}

#pragma mark - Public class methods

- (void)selectGraphBarWithDate:(NSDate *)selectedDate
{
    for (StatsSummary *summary in self.visits.statsData) {
        if ([summary.date isEqualToDate:selectedDate]) {
            NSUInteger index = [self.visits.statsData indexOfObject:summary];
            NSIndexPath *indexPath = [NSIndexPath indexPathForItem:index inSection:0];
            [self.collectionView selectItemAtIndexPath:indexPath animated:NO scrollPosition:UICollectionViewScrollPositionNone];
        }
    }
}

#pragma mark - Property methods

- (void)setVisits:(StatsVisits *)visits
{
    _visits = visits;
    [self calculateMaximumYValue];
}

- (void)setCurrentUnit:(StatsPeriodUnit)currentUnit
{
    _currentUnit = currentUnit;
    [self calculateMaximumYValue];
}

#pragma mark - Private methods

- (void)calculateMaximumYValue
{
    CGFloat maximumY = 0.0f;
    for (StatsSummary *summary in self.visits.statsData) {
        NSNumber *value = [self valueForCurrentTypeFromSummary:summary];
        if (maximumY < value.floatValue) {
            maximumY = value.floatValue;
        }
    }
    
    // Y axis line markers and values
    // Round up and extend past max value to the next step
    NSUInteger yAxisTicks = RecommendedYAxisTicks;
    NSUInteger stepValue = 1;

    if (maximumY > 0) {
        CGFloat s = (CGFloat)maximumY/(CGFloat)yAxisTicks;
        long len = (long)(double)log10(s);
        long div = (long)(double)pow(10, len);
        stepValue = ceil(s / div) * div;

        // Adjust yAxisTicks to accomodate ticks and maximum without too much padding
        yAxisTicks = ceil( maximumY / stepValue ) + 1;
        self.maximumY = stepValue * yAxisTicks;
        self.numberOfYValues = yAxisTicks;
    }
    
    self.numberOfXValues = self.visits.statsData.count;
}

- (NSArray *)barDataForIndexPath:(NSIndexPath *)indexPath
{
//    NSDictionary *categoryData = [self.viewsVisitors viewsVisitorsForUnit:self.currentUnit];
    
    return @[@{ @"color" : [WPStyleGuide textFieldPlaceholderGrey],
                @"selectedColor" : [WPStyleGuide statsLighterOrange],
                @"value" : [self valueForCurrentTypeFromSummary:self.visits.statsData[indexPath.row]],
                @"name" : @"views"
                },
             ];
}

- (NSNumber *)valueForCurrentTypeFromSummary:(StatsSummary *)summary
{
    NSNumber *value = nil;
    switch (self.currentSummaryType) {
        case StatsSummaryTypeViews:
            value = @([summary.views integerValue]);
            break;
        case StatsSummaryTypeVisitors:
            value = @([summary.visitors integerValue]);
            break;
        case StatsSummaryTypeComments:
            value = @([summary.comments integerValue]);
            break;
        case StatsSummaryTypeLikes:
            value = @([summary.likes integerValue]);
            break;
    }

    return value;
}

@end
