#import <UIKit/UIKit.h>
#import "WPStatsViewController.h"

@interface StatsTableViewController : UITableViewController

@property (nonatomic, strong) NSNumber *siteID;
@property (nonatomic, copy)   NSString *oauth2Token;
@property (nonatomic, strong) NSTimeZone *siteTimeZone;
@property (nonatomic, weak) id<WPStatsViewControllerDelegate> statsDelegate;

@end
