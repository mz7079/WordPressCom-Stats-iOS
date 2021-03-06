#import "WPStatsServiceRemote.h"
#import <NSObject-SafeExpectations/NSObject+SafeExpectations.h>
#import "StatsItem.h"
#import "StatsItemAction.h"
#import <NSObject-SafeExpectations/NSObject+SafeExpectations.h>
#import <WordPressShared/NSString+XMLExtensions.h>
#import <WordPressComAnalytics/WPAnalytics.h>
#import <AFNetworking/AFNetworking.h>

// Temporary workaround to handle CocoaPods and how the -Swift.h header is generated
#ifdef MAIN_PROJECT
#import "WordPressComStatsiOS-Swift.h"
#else
#import <WordPressComStatsiOS/WordPressComStatsiOS-Swift.h>
#endif

static NSString *const WordPressComApiClientEndpointURL = @"https://public-api.wordpress.com/rest/v1.1";
static NSInteger const NumberOfDays = 12;

@interface WPStatsServiceRemote ()

@property (nonatomic, copy) NSString *oauth2Token;
@property (nonatomic, strong) NSNumber *siteId;
@property (nonatomic, strong) NSTimeZone *siteTimeZone;
@property (nonatomic, copy) NSString *statsPathPrefix;
@property (nonatomic, copy) NSString *sitesPathPrefix;
@property (nonatomic, strong) NSDateFormatter *deviceDateFormatter;
@property (nonatomic, strong) NSDateFormatter *rfc3339DateFormatter;
@property (nonatomic, strong) NSNumberFormatter *deviceNumberFormatter;
@property (nonatomic, strong) AFHTTPRequestOperationManager *manager;
@property (nonatomic, strong) StatsStringUtilities *stringUtilities;

@end

@implementation WPStatsServiceRemote

- (instancetype)initWithOAuth2Token:(NSString *)oauth2Token siteId:(NSNumber *)siteId andSiteTimeZone:(NSTimeZone *)timeZone
{
    NSParameterAssert(oauth2Token.length > 0);
    NSParameterAssert(siteId != nil);
    NSParameterAssert(timeZone != nil);
    
    self = [super init];
    if (self) {
        _oauth2Token = oauth2Token;
        _siteId = siteId;
        _siteTimeZone = timeZone;
        _sitesPathPrefix = [NSString stringWithFormat:@"%@/sites/%@", WordPressComApiClientEndpointURL, _siteId];
        _statsPathPrefix = [NSString stringWithFormat:@"%@/sites/%@/stats", WordPressComApiClientEndpointURL, _siteId];
        
        _deviceDateFormatter = [NSDateFormatter new];
        _deviceDateFormatter.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
        _deviceDateFormatter.dateFormat = @"yyyy-MM-dd";
        _deviceDateFormatter.timeZone = [NSTimeZone localTimeZone];
        
        _deviceNumberFormatter = [NSNumberFormatter new];
        
        _rfc3339DateFormatter = [[NSDateFormatter alloc] init];
        _rfc3339DateFormatter.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
        _rfc3339DateFormatter.dateFormat = @"yyyy'-'MM'-'dd'T'HH':'mm':'ssZ";
        _rfc3339DateFormatter.timeZone = [NSTimeZone timeZoneForSecondsFromGMT:0];

        _manager = [AFHTTPRequestOperationManager manager];
        _manager.responseSerializer = [AFJSONResponseSerializer serializer];
        [_manager.requestSerializer setValue:[NSString stringWithFormat:@"Bearer %@", _oauth2Token]
                          forHTTPHeaderField:@"Authorization"];
        
        _stringUtilities = [StatsStringUtilities new];
    }
    
    return self;
}


#pragma mark - Public methods


- (void)batchFetchStatsForDate:(NSDate *)date
                          unit:(StatsPeriodUnit)unit
   withVisitsCompletionHandler:(StatsRemoteVisitsCompletion)visitsCompletion
       eventsCompletionHandler:(StatsRemoteItemsCompletion)eventsCompletion
        postsCompletionHandler:(StatsRemoteItemsCompletion)postsCompletion
    referrersCompletionHandler:(StatsRemoteItemsCompletion)referrersCompletion
       clicksCompletionHandler:(StatsRemoteItemsCompletion)clicksCompletion
      countryCompletionHandler:(StatsRemoteItemsCompletion)countryCompletion
       videosCompletionHandler:(StatsRemoteItemsCompletion)videosCompletion
      authorsCompletionHandler:(StatsRemoteItemsCompletion)authorsCompletion
  searchTermsCompletionHandler:(StatsRemoteItemsCompletion)searchTermsCompletion
                 progressBlock:(void (^)(NSUInteger numberOfFinishedOperations, NSUInteger totalNumberOfOperations))progressBlock
    andOverallCompletionHandler:(void (^)())completionHandler
{
    NSMutableArray *mutableOperations = [NSMutableArray new];
    
    if (visitsCompletion) {
        [mutableOperations addObject:[self operationForVisitsForDate:date unit:unit withCompletionHandler:visitsCompletion]];
    }
    if (eventsCompletion) {
        [mutableOperations addObject:[self operationForEventsForDate:date andUnit:unit withCompletionHandler:eventsCompletion]];
    }
    if (postsCompletion) {
        [mutableOperations addObject:[self operationForPostsForDate:date andUnit:unit viewAll:NO withCompletionHandler:postsCompletion]];
    }
    if (referrersCompletion) {
        [mutableOperations addObject:[self operationForReferrersForDate:date andUnit:unit viewAll:NO withCompletionHandler:referrersCompletion]];
    }
    if (clicksCompletion) {
        [mutableOperations addObject:[self operationForClicksForDate:date andUnit:unit viewAll:NO withCompletionHandler:clicksCompletion]];
    }
    if (countryCompletion) {
        [mutableOperations addObject:[self operationForCountryForDate:date andUnit:unit viewAll:NO withCompletionHandler:countryCompletion]];
    }
    if (videosCompletion) {
        [mutableOperations addObject:[self operationForVideosForDate:date andUnit:unit viewAll:NO withCompletionHandler:videosCompletion]];
    }
    if (authorsCompletion) {
        [mutableOperations addObject:[self operationForAuthorsForDate:date andUnit:unit viewAll:NO withCompletionHandler:authorsCompletion]];
    }
    if (searchTermsCompletion) {
        [mutableOperations addObject:[self operationForSearchTermsForDate:date andUnit:unit viewAll:NO withCompletionHandler:searchTermsCompletion]];
    }
    
    NSArray *operations = [AFURLConnectionOperation batchOfRequestOperations:mutableOperations
                                                               progressBlock:progressBlock
                                                             completionBlock:^(NSArray *allOperations)
                           {
                               BOOL zeroOperationsCancelled = [allOperations filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"isCancelled == YES"]].count == 0;
                               if (!zeroOperationsCancelled) {
                                   DDLogWarn(@"At least one operation was cancelled - skipping the completion handler");
                               }
                               
                               if (completionHandler && zeroOperationsCancelled) {
                                   completionHandler();
                               }
                           }];
    
    [self.manager.operationQueue addOperations:operations waitUntilFinished:NO];
    
    if (progressBlock) {
        progressBlock(0, mutableOperations.count);
    }
}


- (void)batchFetchInsightsStatsWithAllTimeCompletionHandler:(StatsRemoteAllTimeCompletion)allTimeCompletion
                                  insightsCompletionHandler:(StatsRemoteInsightsCompletion)insightsCompletion
                              todaySummaryCompletionHandler:(StatsRemoteSummaryCompletion)todaySummaryCompletion
                         latestPostSummaryCompletionHandler:(StatsRemoteLatestPostSummaryCompletion)latestPostCompletion
                                  commentsCompletionHandler:(StatsRemoteItemsCompletion)commentsCompletion
                            tagsCategoriesCompletionHandler:(StatsRemoteItemsCompletion)tagsCategoriesCompletion
                           followersDotComCompletionHandler:(StatsRemoteItemsCompletion)followersDotComCompletion
                            followersEmailCompletionHandler:(StatsRemoteItemsCompletion)followersEmailCompletion
                                 publicizeCompletionHandler:(StatsRemoteItemsCompletion)publicizeCompletion
                                              progressBlock:(void (^)(NSUInteger numberOfFinishedOperations, NSUInteger totalNumberOfOperations))progressBlock
                                andOverallCompletionHandler:(void (^)())completionHandler
{
    NSMutableArray *mutableOperations = [NSMutableArray new];

    if (allTimeCompletion) {
        [mutableOperations addObject:[self operationForAllTimeStatsWithCompletionHandler:allTimeCompletion]];
    }
    if (insightsCompletion) {
        [mutableOperations addObject:[self operationForInsightsStatsWithCompletionHandler:insightsCompletion]];
    }
    if (todaySummaryCompletion) {
        [mutableOperations addObject:[self operationForSummaryForDate:nil andUnit:StatsPeriodUnitDay withCompletionHandler:todaySummaryCompletion]];
    }
    if (latestPostCompletion) {
        [mutableOperations addObject:[self operationForLatestPostSummaryWithCompletionHandler:latestPostCompletion]];
    }
    if (commentsCompletion) {
        [mutableOperations addObject:[self operationForCommentsWithCompletionHandler:commentsCompletion]];
    }
    if (tagsCategoriesCompletion) {
        [mutableOperations addObject:[self operationForTagsCategoriesWithCompletionHandler:tagsCategoriesCompletion]];
    }
    if (followersDotComCompletion) {
        [mutableOperations addObject:[self operationForFollowersOfType:StatsFollowerTypeDotCom viewAll:NO withCompletionHandler:followersDotComCompletion]];
    }
    if (followersEmailCompletion) {
        [mutableOperations addObject:[self operationForFollowersOfType:StatsFollowerTypeEmail viewAll:NO withCompletionHandler:followersEmailCompletion]];
    }
    if (publicizeCompletion) {
        [mutableOperations addObject:[self operationForPublicizeWithCompletionHandler:publicizeCompletion]];
    }
    
    NSArray *operations = [AFURLConnectionOperation batchOfRequestOperations:mutableOperations
                                                               progressBlock:progressBlock
                                                             completionBlock:^(NSArray *allOperations)
                           {
                               BOOL zeroOperationsCancelled = [allOperations filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"isCancelled == YES"]].count == 0;
                               if (!zeroOperationsCancelled) {
                                   DDLogWarn(@"At least one operation was cancelled - skipping the completion handler");
                               }
                               
                               if (completionHandler && zeroOperationsCancelled) {
                                   completionHandler();
                               }
                           }];
    
    [self.manager.operationQueue addOperations:operations waitUntilFinished:NO];
    
    if (progressBlock) {
        progressBlock(0, mutableOperations.count);
    }
}


- (void)fetchPostDetailsStatsForPostID:(NSNumber *)postID
                 withCompletionHandler:(StatsRemotePostDetailsCompletion)completionHandler
{
    NSParameterAssert(postID != nil);
    NSParameterAssert(completionHandler != nil);
    
    NSComparator numberComparator = ^NSComparisonResult(id obj1, id obj2) {
        NSNumber *number1 = [NSNumber numberWithInteger:[obj1 integerValue]];
        NSNumber *number2 = [NSNumber numberWithInteger:[obj2 integerValue]];
        return [number1 compare:number2];
    };

    id handler = ^(AFHTTPRequestOperation *operation, id responseObject)
    {
        NSDictionary *responseDictionary = (NSDictionary *)responseObject;
        NSArray *visitsData = [responseDictionary arrayForKey:@"data"];
        NSDictionary *yearsData = [responseDictionary dictionaryForKey:@"years"];
        NSDictionary *averageData = [responseDictionary dictionaryForKey:@"averages"];
        NSArray *weeksData = [responseDictionary arrayForKey:@"weeks"];
        
        NSMutableArray *visitsArray = [NSMutableArray new];
        NSMutableDictionary *visitsDictionary = [NSMutableDictionary new];
        StatsVisits *visits = [StatsVisits new];
        visits.unit = StatsPeriodUnitDay;
        visits.statsData = visitsArray;
        visits.statsDataByDate = visitsDictionary;
        
        if (visitsData.count > NumberOfDays) {
            visitsData = [visitsData subarrayWithRange:NSMakeRange(visitsData.count - NumberOfDays, NumberOfDays)];
        }

        for (NSArray *visit in visitsData) {
            StatsSummary *statsSummary = [StatsSummary new];
            statsSummary.periodUnit = StatsPeriodUnitDay;
            statsSummary.date = [self deviceLocalDateForString:visit[0] withPeriodUnit:StatsPeriodUnitDay];
            statsSummary.label = [self nicePointNameForDate:statsSummary.date forStatsPeriodUnit:statsSummary.periodUnit];
            statsSummary.views = [self localizedStringForNumber:visit[1]];
            statsSummary.viewsValue = visit[1];
            
            [visitsArray addObject:statsSummary];
            visitsDictionary[statsSummary.date] = statsSummary;
        }
        
        NSMutableArray *yearsItems = [NSMutableArray new];
        NSArray *yearsKeys = [yearsData.allKeys sortedArrayUsingComparator:numberComparator];
        for (NSString *year in yearsKeys) {
            NSDictionary *yearSummary = [yearsData dictionaryForKey:year];
            NSDictionary *months = [yearSummary dictionaryForKey:@"months"];
            NSNumber *yearTotal = [yearSummary numberForKey:@"total"];
            NSArray *monthsKeys = [months.allKeys sortedArrayUsingComparator:numberComparator];
            
            StatsItem *yearItem = [StatsItem new];
            yearItem.label = year;
            yearItem.value = [self localizedStringForNumber:yearTotal];
            [yearsItems addObject:yearItem];
            
            for (NSString *month in monthsKeys) {
                NSNumber *value = [months numberForKey:month];
                
                StatsItem *monthItem = [StatsItem new];
                monthItem.label = [self localizedStringForMonthOrdinal:(NSUInteger)month.integerValue];
                monthItem.value = [self localizedStringForNumber:value];
                [yearItem addChildStatsItem:monthItem];
            }
        }
        
        NSMutableArray *averageItems = [NSMutableArray new];
        NSArray *avgYearsKeys = [averageData.allKeys sortedArrayUsingComparator:numberComparator];
        for (NSString *year in avgYearsKeys) {
            NSDictionary *yearSummary = [averageData dictionaryForKey:year];
            NSDictionary *months = [yearSummary dictionaryForKey:@"months"];
            NSNumber *yearTotal = [yearSummary numberForKey:@"overall"];
            NSArray *monthsKeys = [months.allKeys sortedArrayUsingComparator:numberComparator];
            
            StatsItem *yearItem = [StatsItem new];
            yearItem.label = year;
            yearItem.value = [self localizedStringForNumber:yearTotal];
            [averageItems addObject:yearItem];
            
            for (NSString *month in monthsKeys) {
                NSNumber *value = [months numberForKey:month];
                
                StatsItem *monthItem = [StatsItem new];
                monthItem.label = [self localizedStringForMonthOrdinal:(NSUInteger)month.integerValue];
                monthItem.value = [self localizedStringForNumber:value];
                [yearItem addChildStatsItem:monthItem];
            }
        }
        
        NSMutableArray *weekItems = [NSMutableArray new];
        for (NSDictionary *week in weeksData) {
            NSArray *days = [week arrayForKey:@"days"];
            NSDate *startDate = [self deviceLocalDateForString:[days.firstObject stringForKey:@"day"] withPeriodUnit:StatsPeriodUnitDay];
            NSDate *endDate = [self deviceLocalDateForString:[days.lastObject stringForKey:@"day"] withPeriodUnit:StatsPeriodUnitDay];
            
            StatsItem *weekItem = [StatsItem new];
            weekItem.label = [self localizedStringForPeriodStartDate:startDate endDate:endDate];
            weekItem.value = [self localizedStringForNumber:[week numberForKey:@"total"]];
            [weekItems addObject:weekItem];
            
            for (NSDictionary *day in days) {
                StatsItem *dayItem = [StatsItem new];
                NSDate *date = [self deviceLocalDateForString:[day stringForKey:@"day"] withPeriodUnit:StatsPeriodUnitDay];
                dayItem.label = [self localizedStringWithShortFormatForDate:date];
                dayItem.value = [self localizedStringForNumber:[day numberForKey:@"count"]];
                [weekItem addChildStatsItem:dayItem];
            }
        }

        completionHandler(visits, yearsItems, averageItems, weekItems, nil);
    };
    
    id failureHandler = ^(AFHTTPRequestOperation *operation, NSError *error) {
        if (completionHandler) {
            completionHandler(nil, nil, nil, nil, error);
        }
    };
    
    AFHTTPRequestOperation *operation = [self requestOperationForURLString:[NSString stringWithFormat:@"%@/post/%@", self.statsPathPrefix, postID]
                                                                parameters:nil
                                                                   success:handler
                                                                   failure:failureHandler];
    
    [operation start];
}

- (void)fetchSummaryStatsForDate:(NSDate *)date
           withCompletionHandler:(StatsRemoteSummaryCompletion)completionHandler
{
    AFHTTPRequestOperation *operation = [self operationForSummaryForDate:date andUnit:StatsPeriodUnitDay withCompletionHandler:completionHandler];
    [operation start];
}


- (void)fetchVisitsStatsForDate:(NSDate *)date
                           unit:(StatsPeriodUnit)unit
          withCompletionHandler:(StatsRemoteVisitsCompletion)completionHandler
{
    
    AFHTTPRequestOperation *operation = [self operationForVisitsForDate:date unit:unit withCompletionHandler:completionHandler];
    [operation start];
}


- (void)fetchEventsForDate:(NSDate *)date
                   andUnit:(StatsPeriodUnit)unit
     withCompletionHandler:(StatsRemoteItemsCompletion)completionHandler
{
    NSParameterAssert(date != nil);
    
    AFHTTPRequestOperation *operation = [self operationForEventsForDate:date andUnit:unit withCompletionHandler:completionHandler];
    [operation start];
}


- (void)fetchPostsStatsForDate:(NSDate *)date
                       andUnit:(StatsPeriodUnit)unit
         withCompletionHandler:(StatsRemoteItemsCompletion)completionHandler
{
    NSParameterAssert(date != nil);
    
    AFHTTPRequestOperation *operation = [self operationForPostsForDate:date andUnit:unit viewAll:YES withCompletionHandler:completionHandler];
    [operation start];
}


- (void)fetchReferrersStatsForDate:(NSDate *)date
                           andUnit:(StatsPeriodUnit)unit
             withCompletionHandler:(StatsRemoteItemsCompletion)completionHandler
{
    NSParameterAssert(date != nil);
    
    AFHTTPRequestOperation *operation = [self operationForReferrersForDate:date andUnit:unit viewAll:YES withCompletionHandler:completionHandler];
    [operation start];
}


- (void)fetchClicksStatsForDate:(NSDate *)date
                        andUnit:(StatsPeriodUnit)unit
          withCompletionHandler:(StatsRemoteItemsCompletion)completionHandler
{
    NSParameterAssert(date != nil);
    
    AFHTTPRequestOperation *operation = [self operationForClicksForDate:date andUnit:unit viewAll:YES withCompletionHandler:completionHandler];
    [operation start];
}


- (void)fetchCountryStatsForDate:(NSDate *)date
                         andUnit:(StatsPeriodUnit)unit
           withCompletionHandler:(StatsRemoteItemsCompletion)completionHandler
{
    NSParameterAssert(date != nil);
    
    AFHTTPRequestOperation *operation = [self operationForCountryForDate:date andUnit:unit viewAll:YES withCompletionHandler:completionHandler];
    [operation start];
}


- (void)fetchVideosStatsForDate:(NSDate *)date
                        andUnit:(StatsPeriodUnit)unit
          withCompletionHandler:(StatsRemoteItemsCompletion)completionHandler
{
    NSParameterAssert(date != nil);
    
    AFHTTPRequestOperation *operation = [self operationForVideosForDate:date andUnit:unit viewAll:YES withCompletionHandler:completionHandler];
    [operation start];
}



- (void)fetchAuthorsStatsForDate:(NSDate *)date
                         andUnit:(StatsPeriodUnit)unit
           withCompletionHandler:(StatsRemoteItemsCompletion)completionHandler
{
    NSParameterAssert(date != nil);
    
    AFHTTPRequestOperation *operation = [self operationForAuthorsForDate:date andUnit:unit viewAll:YES withCompletionHandler:completionHandler];
    [operation start];
}


- (void)fetchSearchTermsStatsForDate:(NSDate *)date
                             andUnit:(StatsPeriodUnit)unit
               withCompletionHandler:(StatsRemoteItemsCompletion)completionHandler
{
    NSParameterAssert(date != nil);
    
    AFHTTPRequestOperation *operation = [self operationForSearchTermsForDate:date andUnit:unit viewAll:YES withCompletionHandler:completionHandler];
    [operation start];
}


- (void)fetchCommentsStatsWithCompletionHandler:(StatsRemoteItemsCompletion)completionHandler
{
    AFHTTPRequestOperation *operation = [self operationForCommentsWithCompletionHandler:completionHandler];
    [operation start];
}


- (void)fetchTagsCategoriesStatsWithCompletionHandler:(StatsRemoteItemsCompletion)completionHandler
{
    AFHTTPRequestOperation *operation = [self operationForTagsCategoriesWithCompletionHandler:completionHandler];
    [operation start];
}


- (void)fetchFollowersStatsForFollowerType:(StatsFollowerType)followerType
                     withCompletionHandler:(StatsRemoteItemsCompletion)completionHandler
{
    AFHTTPRequestOperation *operation = [self operationForFollowersOfType:followerType viewAll:YES withCompletionHandler:completionHandler];
    [operation start];
}


- (void)fetchPublicizeStatsWithCompletionHandler:(StatsRemoteItemsCompletion)completionHandler
{
    AFHTTPRequestOperation *operation = [self operationForPublicizeWithCompletionHandler:completionHandler];
    [operation start];
}


- (void)fetchInsightsWithCompletionHandler:(StatsRemoteInsightsCompletion)completionHandler
{
    AFHTTPRequestOperation *operation = [self operationForInsightsStatsWithCompletionHandler:completionHandler];
    
    [operation start];
}

- (void)fetchAllTimeStatsWithCompletionHandler:(StatsRemoteAllTimeCompletion)completionHandler
{
    AFHTTPRequestOperation *operation = [self operationForAllTimeStatsWithCompletionHandler:completionHandler];
    
    [operation start];
}

- (void)fetchLatestPostSummaryWithCompletionHandler:(StatsRemoteLatestPostSummaryCompletion)completionHandler
{
    AFHTTPRequestOperation *operation = [self operationForLatestPostSummaryWithCompletionHandler:completionHandler];
    [operation start];
}

#pragma mark - Private methods to compose request operations to be reusable


- (AFHTTPRequestOperation *)operationForSummaryForDate:(NSDate *)date
                                               andUnit:(StatsPeriodUnit)unit
                                 withCompletionHandler:(StatsRemoteSummaryCompletion)completionHandler
{
    
    id handler = ^(AFHTTPRequestOperation *operation, id responseObject)
    {
        NSDictionary *statsSummaryDict = [self dictionaryFromResponse:responseObject];
        StatsSummary *statsSummary = [StatsSummary new];
        statsSummary.periodUnit = [self periodUnitForString:statsSummaryDict[@"period"]];
        statsSummary.date = [self deviceLocalDateForString:statsSummaryDict[@"date"] withPeriodUnit:unit];
        statsSummary.label = [self nicePointNameForDate:statsSummary.date forStatsPeriodUnit:statsSummary.periodUnit];
        statsSummary.views = [self localizedStringForNumber:[statsSummaryDict numberForKey:@"views"]];
        statsSummary.viewsValue = [statsSummaryDict numberForKey:@"views"];
        statsSummary.visitors = [self localizedStringForNumber:[statsSummaryDict numberForKey:@"visitors"]];
        statsSummary.visitorsValue = [statsSummaryDict numberForKey:@"visitors"];
        statsSummary.likes = [self localizedStringForNumber:[statsSummaryDict numberForKey:@"likes"]];
        statsSummary.likesValue = [statsSummaryDict numberForKey:@"likes"];
        statsSummary.comments = [self localizedStringForNumber:[statsSummaryDict numberForKey:@"comments"]];
        statsSummary.commentsValue = [statsSummaryDict numberForKey:@"comments"];
        
        if (completionHandler) {
            completionHandler(statsSummary, nil);
        }
    };
    
    AFHTTPRequestOperation *operation =  [self requestOperationForURLString:[self urlForSummary]
                                                                 parameters:nil
                                                                    success:handler
                                                                    failure:^(AFHTTPRequestOperation *failedOperation, NSError *error) {
                                                                        if (completionHandler) {
                                                                            completionHandler(nil, error);
                                                                        }
                                                                    }];
    return operation;
}

- (AFHTTPRequestOperation *)operationForAllTimeStatsWithCompletionHandler:(StatsRemoteAllTimeCompletion)completionHandler
{
    id handler = ^(AFHTTPRequestOperation *operation, id responseObject)
    {
        NSDictionary *allTimeDict = [[self dictionaryFromResponse:responseObject] dictionaryForKey:@"stats"];
        NSNumber *postsValue = [allTimeDict numberForKey:@"posts"];
        NSString *posts = [self localizedStringForNumber:postsValue];
        NSNumber *viewsValue = [allTimeDict numberForKey:@"views"];
        NSString *views = [self localizedStringForNumber:viewsValue];
        NSNumber *visitorsValue = [allTimeDict numberForKey:@"visitors"];
        NSString *visitors = [self localizedStringForNumber:visitorsValue];
        NSNumber *bestViewsValue = [allTimeDict numberForKey:@"views_best_day_total"];
        NSString *bestViews = [self localizedStringForNumber:bestViewsValue];
        NSDate *bestViewsOnDate = [self deviceLocalDateForString:[allTimeDict stringForKey:@"views_best_day"] withPeriodUnit:StatsPeriodUnitDay];
        
        NSDateFormatter *dateFormatter = [NSDateFormatter new];
        dateFormatter.dateStyle = NSDateFormatterMediumStyle;
        dateFormatter.timeStyle = NSDateFormatterNoStyle;
        NSString *bestViewsOn = [dateFormatter stringFromDate:bestViewsOnDate];
        
        completionHandler(posts, postsValue, views, viewsValue, visitors, visitorsValue, bestViews, bestViewsValue, bestViewsOn, nil);
    };
    
    id failureHandler = ^(AFHTTPRequestOperation *operation, NSError *error) {
        if (completionHandler) {
            completionHandler(nil, nil, nil, nil, nil, nil, nil, nil, nil, error);
        }
    };
    
    AFHTTPRequestOperation *operation = [self requestOperationForURLString:self.statsPathPrefix
                                                                parameters:nil
                                                                   success:handler
                                                                   failure:failureHandler];
    
    return operation;
}


- (AFHTTPRequestOperation *)operationForInsightsStatsWithCompletionHandler:(StatsRemoteInsightsCompletion)completionHandler
{
    id handler = ^(AFHTTPRequestOperation *operation, id responseObject)
    {
        NSDictionary *insightsDict = [self dictionaryFromResponse:responseObject];
        NSInteger highestHourValue = [insightsDict numberForKey:@"highest_hour"].integerValue;
        NSNumber *highestHourPercentValue = @([insightsDict numberForKey:@"highest_hour_percent"].floatValue / 100.0);
        NSInteger highestDayOfWeekValue = [insightsDict numberForKey:@"highest_day_of_week"].integerValue;
        NSNumber *highestDayPercentValue = @([insightsDict numberForKey:@"highest_day_percent"].floatValue / 100.0);
        
        NSCalendar *calendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
        NSDateComponents *dateComponents = [[NSDateComponents alloc] init];
        // Apple Sunday == 1, WP.com Monday == 0
        dateComponents.weekday = highestDayOfWeekValue == 6 ? 1 : highestDayOfWeekValue + 2;
        dateComponents.weekdayOrdinal = 1;
        dateComponents.month = 5;
        dateComponents.year = 2015;
        dateComponents.hour = highestHourValue;
        NSDate *date = [calendar dateFromComponents:dateComponents];
        
        NSDateFormatter *dateFormatter = [NSDateFormatter new];
        dateFormatter.dateFormat = @"EEEE";
        NSString *highestDayOfWeek = [dateFormatter stringFromDate:date];
        
        dateFormatter.dateFormat = nil;
        dateFormatter.dateStyle = NSDateFormatterNoStyle;
        dateFormatter.timeStyle = NSDateFormatterShortStyle;
        
        NSString *highestHour = [dateFormatter stringFromDate:date];
        
        NSString *highestHourPercent = [self localizedStringForNumber:highestHourPercentValue withNumberStyle:NSNumberFormatterPercentStyle];
        NSString *highestDayPercent = [self localizedStringForNumber:highestDayPercentValue withNumberStyle:NSNumberFormatterPercentStyle];
        
        completionHandler(highestHour, highestHourPercent, highestHourPercentValue, highestDayOfWeek, highestDayPercent, highestDayPercentValue, nil);
    };
    
    id failureHandler = ^(AFHTTPRequestOperation *operation, NSError *error) {
        if (completionHandler) {
            completionHandler(nil, nil, nil, nil, nil, nil, error);
        }
    };
    
    AFHTTPRequestOperation *operation = [self requestOperationForURLString:[NSString stringWithFormat:@"%@/insights", self.statsPathPrefix]
                                                                parameters:nil
                                                                   success:handler
                                                                   failure:failureHandler];
    
    return operation;
}


- (AFHTTPRequestOperation *)operationForLatestPostSummaryWithCompletionHandler:(StatsRemoteLatestPostSummaryCompletion)completionHandler
{
    id postHandler = ^(AFHTTPRequestOperation *operation, id responseObject)
    {
        NSDictionary *postsDict = [self dictionaryFromResponse:responseObject];
        NSDictionary *postDict = [[postsDict arrayForKey:@"posts"] firstObject];
        
        NSNumber *postID = [postDict numberForKey:@"ID"];
        NSString *postTitle = [self.stringUtilities sanitizePostTitle:[postDict stringForKey:@"title"]];
        NSDate *postDate = [self.rfc3339DateFormatter dateFromString:[postDict stringForKey:@"date"]];
        NSString *postURL = [postDict stringForKey:@"URL"];
        NSNumber *likesValue = [postDict numberForKey:@"like_count"];
        NSString *likes = [self localizedStringForNumber:likesValue];
        NSNumber *commentsValue = [[postDict dictionaryForKey:@"discussion"] numberForKey:@"comment_count"];
        NSString *comments = [self localizedStringForNumber:commentsValue];
        
        AFHTTPRequestOperation *operation2 = [self operationForPostViewsWithPostID:postID andCompletionHandler:^(NSString *views, NSNumber *viewsValue, NSError *error) {
            if (completionHandler) {
                completionHandler(postID, postTitle, postURL, postDate, views, viewsValue, likes, likesValue, comments, commentsValue, error);
            }
            
        }];
        
        [operation2 start];
    };
    
    NSDictionary *parameters = @{@"order_by" : @"date",
                                 @"number"   : @1,
                                 @"type"     : @"post",
                                 @"fields"   : @"ID, title, URL, discussion, like_count, date"};
    AFHTTPRequestOperation *operation =  [self requestOperationForURLString:[self urlForPosts]
                                                                 parameters:parameters
                                                                    success:postHandler
                                                                    failure:^(AFHTTPRequestOperation *failedOperation, NSError *error) {
                                                                        
                                                                        if (completionHandler) {
                                                                            completionHandler(nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, error);
                                                                        }
                                                                    }];
    
    return operation;
}


- (AFHTTPRequestOperation *)operationForPostViewsWithPostID:(NSNumber *)postID andCompletionHandler:(void (^)(NSString *views, NSNumber *viewsValue, NSError *error))completionHandler
{
    id postHandler = ^(AFHTTPRequestOperation *operation, id responseObject)
    {
        NSDictionary *postDict = [self dictionaryFromResponse:responseObject];

        NSNumber *viewsValue = [postDict numberForKey:@"views"];
        NSString *views = [self localizedStringForNumber:viewsValue];
        
        if (completionHandler) {
            completionHandler(views, viewsValue, nil);
        }
    };

    NSString *viewsURL = [NSString stringWithFormat:@"%@/post/%@", self.statsPathPrefix, postID];
    
    AFHTTPRequestOperation *operation = [self requestOperationForURLString:viewsURL
                                                                parameters:@{@"fields" : @"views"}
                                                                   success:postHandler
                                                                   failure:^(AFHTTPRequestOperation *failedOperation, NSError *error) {
                                                                       if (completionHandler) {
                                                                           completionHandler(nil, nil, error);
                                                                       }
                                                                   }];
    return operation;
}


- (AFHTTPRequestOperation *)operationForVisitsForDate:(NSDate *)date
                                                 unit:(StatsPeriodUnit)unit
                                withCompletionHandler:(StatsRemoteVisitsCompletion)completionHandler
{
    id handler = ^(AFHTTPRequestOperation *operation, id responseObject)
    {
        NSDictionary *statsVisitsDict = [self dictionaryFromResponse:responseObject];
        
        StatsVisits *statsVisits = [StatsVisits new];
        statsVisits.date = [self deviceLocalDateForString:statsVisitsDict[@"date"] withPeriodUnit:unit];
        
        NSArray *fields = (NSArray *)statsVisitsDict[@"fields"];
        
        NSUInteger periodIndex = [fields indexOfObject:@"period"];
        NSUInteger viewsIndex = [fields indexOfObject:@"views"];
        NSUInteger visitorsIndex = [fields indexOfObject:@"visitors"];
        NSUInteger likesIndex = [fields indexOfObject:@"likes"];
        NSUInteger commentsIndex = [fields indexOfObject:@"comments"];
        
        NSMutableArray *array = [NSMutableArray new];
        NSMutableDictionary *dictionary = [NSMutableDictionary new];
        for (NSArray *period in statsVisitsDict[@"data"]) {
            StatsSummary *periodSummary = [StatsSummary new];
            periodSummary.periodUnit = unit;
            periodSummary.date = [self deviceLocalDateForString:period[periodIndex] withPeriodUnit:unit];
            periodSummary.label = [self nicePointNameForDate:periodSummary.date forStatsPeriodUnit:periodSummary.periodUnit];
            periodSummary.views = [self localizedStringForNumber:period[viewsIndex]];
            periodSummary.viewsValue = period[viewsIndex];
            periodSummary.visitors = [self localizedStringForNumber:period[visitorsIndex]];
            periodSummary.visitorsValue = period[visitorsIndex];
            periodSummary.likes = [self localizedStringForNumber:period[likesIndex]];
            periodSummary.likesValue = period[likesIndex];
            periodSummary.comments = [self localizedStringForNumber:period[commentsIndex]];
            periodSummary.commentsValue = period[commentsIndex];
            
            if (periodSummary.date) {
                [array addObject:periodSummary];
                dictionary[periodSummary.date] = periodSummary;
            } else {
                DDLogError(@"operationForVisitsForDate resulted in nil date: raw date: %@", period[periodIndex]);
                [WPAnalytics track:WPAnalyticsStatLogSpecialCondition withProperties:@{@"error_condition" : @"WPStatsServiceRemote operationForVisitsForDate:andUnit:withCompletionHandler",
                                                                                       @"error_details" : [NSString stringWithFormat:@"Date in raw format: %@, period: %@ ", period[periodIndex], @(unit)],
                                                                                       @"blog_id" : self.siteId}];
            }
        }
        
        statsVisits.statsData = array;
        statsVisits.statsDataByDate = dictionary;
        
        if (completionHandler) {
            completionHandler(statsVisits, nil);
        }
    };
    
    NSDictionary *parameters = @{@"quantity" : @(NumberOfDays),
                                 @"unit"     : [self stringForPeriodUnit:unit],
                                 @"date"     : [self deviceLocalStringForDate:date]};
    
    AFHTTPRequestOperation *operation =  [self requestOperationForURLString:[self urlForVisits]
                                                                 parameters:parameters
                                                                    success:handler
                                                                    failure:^(AFHTTPRequestOperation *failedOperation, NSError *error) {
                                                                        if (completionHandler) {
                                                                            StatsVisits *visits = [StatsVisits new];
                                                                            visits.errorWhileRetrieving = YES;
                                                                            
                                                                            completionHandler(visits, error);
                                                                        }
                                                                    }];
    return operation;
}


- (AFHTTPRequestOperation *)operationForEventsForDate:(NSDate *)date
                                              andUnit:(StatsPeriodUnit)unit
                                withCompletionHandler:(StatsRemoteItemsCompletion)completionHandler
{
    id handler = ^(AFHTTPRequestOperation *operation, id responseObject)
    {
        NSDictionary *rootDict = [self dictionaryFromResponse:responseObject];
        NSArray *posts = [rootDict arrayForKey:@"posts"];
        NSMutableArray *items = [NSMutableArray new];
        
        for (NSDictionary *post in posts) {
            StatsItem *item = [StatsItem new];
            item.itemID = [post numberForKey:@"ID"];
            item.label = [self.stringUtilities sanitizePostTitle:[post stringForKey:@"title"]];
            
            StatsItemAction *itemAction = [StatsItemAction new];
            itemAction.defaultAction = YES;
            itemAction.url = [NSURL URLWithString:[post stringForKey:@"URL"]];
            item.actions = @[itemAction];
            
            [items addObject:item];
        }
        
        if (completionHandler) {
            completionHandler(items, nil, NO, nil);
        }
    };
    
    NSDictionary *parameters = @{@"after"   : [self deviceLocalISOStringForDate:[self calculateStartDateForPeriodUnit:unit withEndDate:date]],
                                 @"before"  : [self deviceLocalISOStringForDate:date],
                                 @"number"  : @10,
                                 @"fields"  : @"ID, title, URL"};
    AFHTTPRequestOperation *operation =  [self requestOperationForURLString:[self urlForPosts]
                                                                 parameters:parameters
                                                                    success:handler
                                                                    failure:[self failureForCompletionHandler:completionHandler]];
    return operation;
}


- (AFHTTPRequestOperation *)operationForPostsForDate:(NSDate *)date
                                             andUnit:(StatsPeriodUnit)unit
                                             viewAll:(BOOL)viewAll
                               withCompletionHandler:(StatsRemoteItemsCompletion)completionHandler
{
    id handler = ^(AFHTTPRequestOperation *operation, id responseObject)
    {
        NSDictionary *statsPostsDict = [self dictionaryFromResponse:responseObject];
        NSDictionary *days = [statsPostsDict dictionaryForKey:@"days"];
        id firstKey = days.allKeys.firstObject;
        NSDictionary *firstDay = [days dictionaryForKey:firstKey];
        NSArray *postViews = [firstDay arrayForKey:@"postviews"];
        NSString *totalViews = [self localizedStringForNumber:[firstDay numberForKey:@"total_views"]];
        BOOL moreViewsAvailable = [firstDay numberForKey:@"other_views"].integerValue > 0;
        NSMutableArray *items = [NSMutableArray new];
        
        for (NSDictionary *post in postViews) {
            StatsItem *statsItem = [StatsItem new];
            statsItem.itemID = post[@"id"];
            statsItem.value = [self localizedStringForNumber:[post numberForKey:@"views"]];
            statsItem.label = [self.stringUtilities sanitizePostTitle:[post stringForKey:@"title"]];
            
            id url = post[@"href"];
            if ([url isKindOfClass:[NSString class]]) {
                StatsItemAction *statsItemAction = [StatsItemAction new];
                statsItemAction.url = [NSURL URLWithString:url];
                statsItemAction.defaultAction = YES;

                statsItem.actions = @[statsItemAction];
            }
            
            [items addObject:statsItem];
        }
        
        
        if (completionHandler) {
            completionHandler(items, totalViews, moreViewsAvailable, nil);
        }
    };
    
    NSDictionary *parameters = @{@"period" : [self stringForPeriodUnit:unit],
                                 @"date"   : [self deviceLocalStringForDate:date],
                                 @"max"    : (viewAll ? @0 : @10) };
    AFHTTPRequestOperation *operation =  [self requestOperationForURLString:[self urlForTopPosts]
                                                                 parameters:parameters
                                                                    success:handler
                                                                    failure:[self failureForCompletionHandler:completionHandler]];
    return operation;
}


- (AFHTTPRequestOperation *)operationForReferrersForDate:(NSDate *)date
                                                 andUnit:(StatsPeriodUnit)unit
                                                 viewAll:(BOOL)viewAll
                                   withCompletionHandler:(StatsRemoteItemsCompletion)completionHandler
{
    id handler = ^(AFHTTPRequestOperation *operation, id responseObject)
    {
        NSDictionary *referrersDict = [self dictionaryFromResponse:responseObject];
        NSDictionary *days = [referrersDict dictionaryForKey:@"days"];
        id firstKey = days.allKeys.firstObject;
        NSDictionary *firstDay = [days dictionaryForKey:firstKey];
        NSArray *groups = [firstDay arrayForKey:@"groups"];
        NSString *totalViews = [self localizedStringForNumber:[firstDay numberForKey:@"total_views"]];
        BOOL moreViewsAvailable = [firstDay numberForKey:@"other_views"].integerValue > 0;
        NSMutableArray *items = [NSMutableArray new];
        
        for (NSDictionary *group in groups) {
            StatsItem *statsItem = [StatsItem new];
            statsItem.label = [group stringForKey:@"name"];
            statsItem.value = [self localizedStringForNumber:[group numberForKey:@"total"]];
            statsItem.iconURL = [NSURL URLWithString:[group stringForKey:@"icon"]];
            
            NSString *url = [group stringForKey:@"url"];
            if (url) {
                StatsItemAction *action = [StatsItemAction new];
                action.url = [NSURL URLWithString:url];
                action.defaultAction = YES;
                statsItem.actions = @[action];
            }
            
            NSArray *results = [group arrayForKey:@"results"];
            for (id result in results) {
                if ([result isKindOfClass:[NSDictionary class]]) {
                    StatsItem *resultItem = [StatsItem new];
                    resultItem.label = [result stringForKey:@"name"];
                    resultItem.iconURL = [NSURL URLWithString:[result stringForKey:@"icon"]];
                    resultItem.value = [self localizedStringForNumber:[result numberForKey:@"views"]];
                    
                    NSString *resultItemURL = [result stringForKey:@"url"];
                    if (resultItemURL) {
                        StatsItemAction *action = [StatsItemAction new];
                        action.url = [NSURL URLWithString:resultItemURL];
                        action.defaultAction = YES;
                        resultItem.actions = @[action];
                    }
                    
                    [statsItem addChildStatsItem:resultItem];
                    
                    NSArray *children = [result arrayForKey:@"children"];
                    for (NSDictionary *child in children) {
                        StatsItem *childItem = [StatsItem new];
                        childItem.label = [child stringForKey:@"name"];
                        childItem.iconURL = [NSURL URLWithString:[child stringForKey:@"icon"]];
                        childItem.value = [self localizedStringForNumber:[child numberForKey:@"views"]];
                        
                        NSString *childItemURL = [child stringForKey:@"url"];
                        if (childItemURL) {
                            StatsItemAction *action = [StatsItemAction new];
                            action.url = [NSURL URLWithString:childItemURL];
                            action.defaultAction = YES;
                            childItem.actions = @[action];
                        }
                        
                        [resultItem addChildStatsItem:childItem];
                    }
                }
            }
            
            [items addObject:statsItem];
        }
        
        
        if (completionHandler) {
            completionHandler(items, totalViews, moreViewsAvailable, nil);
        }
    };
    
    NSDictionary *parameters = @{@"period" : [self stringForPeriodUnit:unit],
                                 @"date"   : [self deviceLocalStringForDate:date],
                                 @"max"    : (viewAll ? @0 : @10) };
    
    AFHTTPRequestOperation *operation = [self requestOperationForURLString:[self urlForReferrers]
                                                                parameters:parameters
                                                                   success:handler
                                                                   failure:[self failureForCompletionHandler:completionHandler]];
    
    return operation;
}


- (AFHTTPRequestOperation *)operationForClicksForDate:(NSDate *)date
                                              andUnit:(StatsPeriodUnit)unit
                                              viewAll:(BOOL)viewAll
                               withCompletionHandler:(StatsRemoteItemsCompletion)completionHandler
{
    id handler = ^(AFHTTPRequestOperation *operation, id responseObject)
    {
        NSDictionary *referrersDict = [self dictionaryFromResponse:responseObject];
        NSDictionary *days = [referrersDict dictionaryForKey:@"days"];
        id firstKey = days.allKeys.firstObject;
        NSDictionary *firstDay = [days dictionaryForKey:firstKey];
        NSArray *clicks = [firstDay arrayForKey:@"clicks"];
        NSString *totalClicks = [self localizedStringForNumber:[firstDay numberForKey:@"total_clicks"]];
        BOOL moreClicksAvailable = [firstDay numberForKey:@"other_clicks"].integerValue > 0;
        NSMutableArray *items = [NSMutableArray new];
        
        for (NSDictionary *click in clicks) {
            StatsItem *statsItem = [StatsItem new];
            statsItem.label = [click stringForKey:@"name"];
            statsItem.value = [self localizedStringForNumber:[click numberForKey:@"views"]];
            statsItem.iconURL = [NSURL URLWithString:[click stringForKey:@"icon"]];
            
            NSString *url = [click stringForKey:@"url"];
            if (url) {
                StatsItemAction *action = [StatsItemAction new];
                action.url = [NSURL URLWithString:url];
                action.defaultAction = YES;
                statsItem.actions = @[action];
            }
            
            NSArray *children = [click arrayForKey:@"children"];
            for (NSDictionary *child in children) {
                StatsItem *childItem = [StatsItem new];
                childItem.label = [child stringForKey:@"name"];
                childItem.iconURL = [NSURL URLWithString:[child stringForKey:@"icon"]];
                childItem.value = [self localizedStringForNumber:[child numberForKey:@"views"]];
                
                NSString *childItemURL = [child stringForKey:@"url"];
                if (childItemURL) {
                    StatsItemAction *action = [StatsItemAction new];
                    action.url = [NSURL URLWithString:childItemURL];
                    action.defaultAction = YES;
                    childItem.actions = @[action];
                }
                
                [statsItem addChildStatsItem:childItem];
            }
            
            [items addObject:statsItem];
        }
        
        
        if (completionHandler) {
            completionHandler(items, totalClicks, moreClicksAvailable, nil);
        }
    };
    
    NSDictionary *parameters = @{@"period" : [self stringForPeriodUnit:unit],
                                 @"date"   : [self deviceLocalStringForDate:date],
                                 @"max"    : (viewAll ? @0 : @10) };
    
    AFHTTPRequestOperation *operation = [self requestOperationForURLString:[self urlForClicks]
                                                                parameters:parameters
                                                                   success:handler
                                                                   failure:[self failureForCompletionHandler:completionHandler]];
    return operation;
}


- (AFHTTPRequestOperation *)operationForCountryForDate:(NSDate *)date
                                               andUnit:(StatsPeriodUnit)unit
                                               viewAll:(BOOL)viewAll
                                 withCompletionHandler:(StatsRemoteItemsCompletion)completionHandler
{
    id handler = ^(AFHTTPRequestOperation *operation, id responseObject)
    {
        NSDictionary *countryViewsDict = [self dictionaryFromResponse:responseObject];
        NSDictionary *days = [countryViewsDict dictionaryForKey:@"days"];
        id firstKey = days.allKeys.firstObject;
        NSDictionary *firstDay = [days dictionaryForKey:firstKey];
        NSDictionary *countryInfoDict = [countryViewsDict dictionaryForKey:@"country-info"];
        NSArray *views = [firstDay arrayForKey:@"views"];
        NSString *totalViews = [self localizedStringForNumber:[firstDay numberForKey:@"total_views"]];
        BOOL moreViewsAvailable = [firstDay numberForKey:@"other_views"].integerValue > 0;
        NSMutableArray *items = [NSMutableArray new];
        
        for (NSDictionary *view in views) {
            NSString *key = [view stringForKey:@"country_code"];
            StatsItem *statsItem = [StatsItem new];
            statsItem.label = [countryInfoDict[key] stringForKey:@"country_full"];
            statsItem.value = [self localizedStringForNumber:[view numberForKey:@"views"]];

            NSString *urlString = [countryInfoDict[key] stringForKey:@"flat_flag_icon"];
            if (urlString.length > 0) {
                NSURLComponents *components = [NSURLComponents componentsWithString:urlString];
                components.query = @"s=60";
                statsItem.iconURL = components.URL;
            }
            
            [items addObject:statsItem];
        }
        
        if (completionHandler) {
            completionHandler(items, totalViews, moreViewsAvailable, nil);
        }
    };
    
    NSDictionary *parameters = @{@"period" : [self stringForPeriodUnit:unit],
                                 @"date"   : [self deviceLocalStringForDate:date],
                                 @"max"    : (viewAll ? @0 : @10) };
    
    AFHTTPRequestOperation *operation = [self requestOperationForURLString:[self urlForCountryViews]
                                                                parameters:parameters
                                                                   success:handler
                                                                   failure:[self failureForCompletionHandler:completionHandler]];

    return operation;
}


- (AFHTTPRequestOperation *)operationForVideosForDate:(NSDate *)date
                                              andUnit:(StatsPeriodUnit)unit
                                              viewAll:(BOOL)viewAll
                                withCompletionHandler:(StatsRemoteItemsCompletion)completionHandler
{
    id handler = ^(AFHTTPRequestOperation *operation, id responseObject)
    {
        NSDictionary *videosDict = [self dictionaryFromResponse:responseObject];
        NSDictionary *days = [videosDict dictionaryForKey:@"days"];
        id firstKey = days.allKeys.firstObject;
        NSDictionary *firstDay = [days dictionaryForKey:firstKey];
        NSArray *playsArray = [firstDay arrayForKey:@"plays"];
        NSString *totalPlays = [self localizedStringForNumber:[firstDay numberForKey:@"total_plays"]];
        BOOL morePlaysAvailable = [firstDay numberForKey:@"other_plays"].integerValue > 0;
        NSMutableArray *items = [NSMutableArray new];
        
        for (NSDictionary *play in playsArray) {
            StatsItem *statsItem = [StatsItem new];
            statsItem.itemID = [play numberForKey:@"post_id"];
            statsItem.label = [self.stringUtilities sanitizePostTitle:[play stringForKey:@"title"]];
            statsItem.value = [self localizedStringForNumber:[play numberForKey:@"plays"]];

            NSString *url = [play stringForKey:@"url"];
            if (url) {
                StatsItemAction *action = [StatsItemAction new];
                action.url = [NSURL URLWithString:url];
                action.defaultAction = YES;
                statsItem.actions = @[action];
            }

            [items addObject:statsItem];
        }
        
        if (completionHandler) {
            completionHandler(items, totalPlays, morePlaysAvailable, nil);
        }
    };
    
    NSDictionary *parameters = @{@"period" : [self stringForPeriodUnit:unit],
                                 @"date"   : [self deviceLocalStringForDate:date],
                                 @"max"    : (viewAll ? @0 : @10) };
    
    AFHTTPRequestOperation *operation = [self requestOperationForURLString:[self urlForVideos]
                                                                parameters:parameters
                                                                   success:handler
                                                                   failure:[self failureForCompletionHandler:completionHandler]];
    
    return operation;
}


- (AFHTTPRequestOperation *)operationForAuthorsForDate:(NSDate *)date
                                               andUnit:(StatsPeriodUnit)unit
                                               viewAll:(BOOL)viewAll
                                 withCompletionHandler:(StatsRemoteItemsCompletion)completionHandler
{
    id handler = ^(AFHTTPRequestOperation *operation, id responseObject)
    {
        NSDictionary *responseDict = [self dictionaryFromResponse:responseObject];
        NSDictionary *days = [responseDict dictionaryForKey:@"days"];
        id firstKey = days.allKeys.firstObject;
        NSDictionary *firstDay = [days dictionaryForKey:firstKey];
        NSArray *authorsArray = [firstDay arrayForKey:@"authors"];
        BOOL moreAuthorsAvailable = [firstDay numberForKey:@"other_views"].integerValue > 0;
        NSMutableArray *items = [NSMutableArray new];
        
        for (NSDictionary *author in authorsArray) {
            StatsItem *item = [StatsItem new];
            item.label = [author stringForKey:@"name"];
            item.value = [self localizedStringForNumber:[author numberForKey:@"views"]];
            NSString *urlString = [author stringForKey:@"avatar"];
            if (urlString.length > 0) {
                NSURLComponents *components = [NSURLComponents componentsWithString:urlString];
                components.query = @"d=mm&s=60";
                item.iconURL = components.URL;
            }

            NSArray *posts = [author arrayForKey:@"posts"];
            for (NSDictionary *post in posts) {
                StatsItem *postItem = [StatsItem new];
                postItem.itemID = [post numberForKey:@"id"];
                postItem.label = [self.stringUtilities sanitizePostTitle:[post stringForKey:@"title"]];
                postItem.value = [self localizedStringForNumber:[post numberForKey:@"views"]];
                
                StatsItemAction *itemAction = [StatsItemAction new];
                itemAction.defaultAction = YES;
                itemAction.url = [NSURL URLWithString:[post stringForKey:@"URL"]];
                postItem.actions = @[itemAction];
                
                [item addChildStatsItem:postItem];
            }

            [items addObject:item];
        }

        if (completionHandler) {
            completionHandler(items, nil, moreAuthorsAvailable, nil);
        }
    };
    
    NSDictionary *parameters = @{@"period" : [self stringForPeriodUnit:unit],
                                 @"date"   : [self deviceLocalStringForDate:date],
                                 @"max"    : (viewAll ? @0 : @10) };
    
    AFHTTPRequestOperation *operation = [self requestOperationForURLString:[self urlForAuthors]
                                                                parameters:parameters
                                                                   success:handler
                                                                   failure:[self failureForCompletionHandler:completionHandler]];
    
    return operation;
}




- (AFHTTPRequestOperation *)operationForSearchTermsForDate:(NSDate *)date
                                                   andUnit:(StatsPeriodUnit)unit
                                                   viewAll:(BOOL)viewAll
                                     withCompletionHandler:(StatsRemoteItemsCompletion)completionHandler
{
    id handler = ^(AFHTTPRequestOperation *operation, id responseObject)
    {
        NSDictionary *responseDict = [self dictionaryFromResponse:responseObject];
        NSDictionary *days = [responseDict dictionaryForKey:@"days"];
        id firstKey = days.allKeys.firstObject;
        NSDictionary *firstDay = [days dictionaryForKey:firstKey];
        NSArray *termsArray = [firstDay arrayForKey:@"search_terms"];
        BOOL moreTermsAvailable = [firstDay numberForKey:@"other_search_terms"].integerValue > 0;
        NSMutableArray *items = [NSMutableArray new];
        
        for (NSDictionary *term in termsArray) {
            StatsItem *item = [StatsItem new];
            item.label = [term stringForKey:@"term"];
            item.value = [self localizedStringForNumber:[term numberForKey:@"views"]];
            [items addObject:item];
        }
        
        NSNumber *encryptedSearchTermsViews = [firstDay numberForKey:@"encrypted_search_terms"];
        if (![encryptedSearchTermsViews isEqualToNumber:@0]) {
            StatsItem *item = [StatsItem new];
            item.label = NSLocalizedString(@"Unknown Search Terms", @"");
            item.value = [self localizedStringForNumber:encryptedSearchTermsViews];
            
            StatsItemAction *itemAction = [StatsItemAction new];
            itemAction.defaultAction = YES;
            itemAction.url = [NSURL URLWithString:@"http://en.support.wordpress.com/stats/#search-engine-terms"];
            item.actions = @[itemAction];
            
            [items addObject:item];
        }

        if (completionHandler) {
            completionHandler(items, nil, moreTermsAvailable, nil);
        }
    };
    
    NSDictionary *parameters = @{@"period" : [self stringForPeriodUnit:unit],
                                 @"date"   : [self deviceLocalStringForDate:date],
                                 @"max"    : (viewAll ? @0 : @10) };
    
    AFHTTPRequestOperation *operation = [self requestOperationForURLString:[self urlForSearchTerms]
                                                                parameters:parameters
                                                                   success:handler
                                                                   failure:[self failureForCompletionHandler:completionHandler]];
    
    return operation;
}


- (AFHTTPRequestOperation *)operationForCommentsWithCompletionHandler:(StatsRemoteItemsCompletion)completionHandler
{
    id handler = ^(AFHTTPRequestOperation *operation, id responseObject)
    {
        NSMutableArray *authorItems = [NSMutableArray new];
        NSMutableArray *postsItems = [NSMutableArray new];
        
        NSDictionary *responseDict = [self dictionaryFromResponse:responseObject];
        NSArray *authors = [responseDict arrayForKey:@"authors"];
        NSArray *posts = [responseDict arrayForKey:@"posts"];
        
        for (NSDictionary *author in authors) {
            StatsItem *item = [StatsItem new];
            item.label = [author stringForKey:@"name"];
            NSString *urlString = [author stringForKey:@"gravatar"];
            if (urlString.length > 0) {
                NSURLComponents *components = [NSURLComponents componentsWithString:urlString];
                components.query = @"d=mm&s=60";
                item.iconURL = components.URL;
            }
            item.value = [self localizedStringForNumber:[author numberForKey:@"comments"]];
            
            [authorItems addObject:item];
        }
        
        for (NSDictionary *post in posts) {
            StatsItem *item = [StatsItem new];
            item.label = [post stringForKey:@"name"];
            item.itemID = [post numberForKey:@"id"];
            item.value = [self localizedStringForNumber:[post numberForKey:@"comments"]];
            
            NSString *linkURL = [post stringForKey:@"link"];
            if (linkURL.length > 0) {
                StatsItemAction *itemAction = [StatsItemAction new];
                itemAction.url = [NSURL URLWithString:linkURL];
                itemAction.defaultAction = YES;
                item.actions = @[itemAction];
            }
            
            [postsItems addObject:item];
        }
        
        if (completionHandler) {
            // More not available with comments
            completionHandler(@[authorItems, postsItems], nil, false, nil);
        }
    };
    
    AFHTTPRequestOperation *operation = [self requestOperationForURLString:[self urlForComments]
                                                                parameters:nil
                                                                   success:handler
                                                                   failure:[self failureForCompletionHandler:completionHandler]];
    
    return operation;
}


- (AFHTTPRequestOperation *)operationForTagsCategoriesWithCompletionHandler:(StatsRemoteItemsCompletion)completionHandler
{
    id handler = ^(AFHTTPRequestOperation *operation, id responseObject)
    {
        NSDictionary *responseDict = [self dictionaryFromResponse:responseObject];
        NSArray *tagGroups = [responseDict arrayForKey:@"tags"];
        NSMutableArray *items = [NSMutableArray new];
        
        for (NSDictionary *tagGroup in tagGroups) {
            NSArray *tags = [tagGroup arrayForKey:@"tags"];
            
            if (tags.count == 1) {
                NSDictionary *theTag = tags[0];
                StatsItem *statsItem = [StatsItem new];
                statsItem.label = [theTag stringForKey:@"name"];
                statsItem.alternateIconValue = [theTag stringForKey:@"type"];
                statsItem.value = [self localizedStringForNumber:[tagGroup numberForKey:@"views"]];
                NSString *linkURL = [theTag stringForKey:@"link"];
                if (linkURL.length > 0) {
                    StatsItemAction *itemAction = [StatsItemAction new];
                    itemAction.url = [NSURL URLWithString:linkURL];
                    itemAction.defaultAction = YES;
                    statsItem.actions = @[itemAction];
                }
                
                [items addObject:statsItem];
            } else {
                NSMutableString *tagLabel = [NSMutableString new];
                
                StatsItem *statsItem = [StatsItem new];
                for (NSDictionary *subTag in tags) {
                    
                    StatsItem *childItem = [StatsItem new];
                    childItem.label = [subTag stringForKey:@"name"];
                    childItem.alternateIconValue = [subTag stringForKey:@"type"];
                    NSString *linkURL = [subTag stringForKey:@"link"];
                    if (linkURL.length > 0) {
                        StatsItemAction *itemAction = [StatsItemAction new];
                        itemAction.url = [NSURL URLWithString:linkURL];
                        itemAction.defaultAction = YES;
                        childItem.actions = @[itemAction];
                    }

                    [tagLabel appendFormat:@"%@, ", childItem.label];
                    
                    [statsItem addChildStatsItem:childItem];
                }
                
                NSMutableCharacterSet *whitespaceCharacters = [NSMutableCharacterSet whitespaceCharacterSet];
                [whitespaceCharacters addCharactersInString:@","];
                NSString *trimmedLabel = [tagLabel stringByTrimmingCharactersInSet:whitespaceCharacters];
                statsItem.label = trimmedLabel;
                statsItem.value = [self localizedStringForNumber:[tagGroup numberForKey:@"views"]];
                
                [items addObject:statsItem];
            }
        }
        
        if (completionHandler) {
            // More not available with tags
            completionHandler(items, nil, false, nil);
        }
    };
    
    AFHTTPRequestOperation *operation = [self requestOperationForURLString:[self urlForTagsCategories]
                                                                parameters:nil
                                                                   success:handler
                                                                   failure:[self failureForCompletionHandler:completionHandler]];
    return operation;}


- (AFHTTPRequestOperation *)operationForFollowersOfType:(StatsFollowerType)followerType
                                                viewAll:(BOOL)viewAll
                                  withCompletionHandler:(StatsRemoteItemsCompletion)completionHandler
{
    id handler = ^(AFHTTPRequestOperation *operation, id responseObject)
    {
        NSDictionary *responseDict = [self dictionaryFromResponse:responseObject];
        NSArray *subscribers = [responseDict arrayForKey:@"subscribers"];
        NSMutableArray *items = [NSMutableArray new];
        NSString *totalKey = followerType == StatsFollowerTypeDotCom ? @"total_wpcom" : @"total_email";
        NSString *totalFollowers = [self localizedStringForNumber:[responseDict numberForKey:totalKey]];
        BOOL moreFollowersAvailable = [responseDict numberForKey:@"pages"].integerValue > 1;
        
        NSDateFormatter *dateFormatter = [NSDateFormatter new];
        dateFormatter.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
        dateFormatter.dateFormat = @"yyyy-mm-dd hh:mi:ss";
        
        for (NSDictionary *subscriber in subscribers) {
            StatsItem *statsItem = [StatsItem new];
            statsItem.label = [subscriber stringForKey:@"label"];
            
            NSString *urlString = [subscriber stringForKey:@"avatar"];
            if (urlString.length > 0) {
                NSURLComponents *components = [NSURLComponents componentsWithString:urlString];
                components.query = @"d=mm&s=60";
                statsItem.iconURL = components.URL;
            }

            statsItem.date = [self.rfc3339DateFormatter dateFromString:[subscriber stringForKey:@"date_subscribed"]];
            
            
            [items addObject:statsItem];
        }
        
        if (completionHandler) {
            completionHandler(items, totalFollowers, moreFollowersAvailable, nil);
        }
    };
    
    NSDictionary *parameters = @{@"type"   : followerType == StatsFollowerTypeDotCom ? @"wpcom" : @"email",
                                 @"max"    : (viewAll ? @0 : @7) };
    
    AFHTTPRequestOperation *operation = [self requestOperationForURLString:[self urlForFollowers]
                                                                parameters:parameters
                                                                   success:handler
                                                                   failure:[self failureForCompletionHandler:completionHandler]];
    
    return operation;
}


- (AFHTTPRequestOperation *)operationForPublicizeWithCompletionHandler:(StatsRemoteItemsCompletion)completionHandler
{
    id handler = ^(AFHTTPRequestOperation *operation, id responseObject)
    {
        NSDictionary *responseDict = [self dictionaryFromResponse:responseObject];
        NSArray *services = [responseDict arrayForKey:@"services"];
        NSMutableArray *items = [NSMutableArray new];
        
        for (NSDictionary *service in services) {
            StatsItem *statsItem = [StatsItem new];
            NSString *serviceID = [service stringForKey:@"service"];
            NSString *serviceLabel = serviceID;
            NSURL *iconURL = nil;
            
            if ([serviceID isEqualToString:@"facebook"]) {
                serviceLabel = @"Facebook";
                iconURL = [NSURL URLWithString:@"https://secure.gravatar.com/blavatar/2343ec78a04c6ea9d80806345d31fd78?s=60"];
            } else if ([serviceID isEqualToString:@"twitter"]) {
                serviceLabel = @"Twitter";
                iconURL = [NSURL URLWithString:@"https://secure.gravatar.com/blavatar/7905d1c4e12c54933a44d19fcd5f9356?s=60"];
            } else if ([serviceID isEqualToString:@"tumblr"]) {
                serviceLabel = @"Tumblr";
                iconURL = [NSURL URLWithString:@"https://secure.gravatar.com/blavatar/84314f01e87cb656ba5f382d22d85134?s=60"];
            } else if ([serviceID isEqualToString:@"google_plus"]) {
                serviceLabel = @"Google+";
                iconURL = [NSURL URLWithString:@"https://secure.gravatar.com/blavatar/4a4788c1dfc396b1f86355b274cc26b3?s=60"];
            } else if ([serviceID isEqualToString:@"linkedin"]) {
                serviceLabel = @"LinkedIn";
                iconURL = [NSURL URLWithString:@"https://secure.gravatar.com/blavatar/f54db463750940e0e7f7630fe327845e?s=60"];
            } else if ([serviceID isEqualToString:@"path"]) {
                serviceLabel = @"Path";
                iconURL = [NSURL URLWithString:@"https://secure.gravatar.com/blavatar/3a03c8ce5bf1271fb3760bb6e79b02c1?s=60"];
            }
            
            statsItem.label = serviceLabel;
            statsItem.iconURL = iconURL;
            statsItem.value = [self localizedStringForNumber:[service numberForKey:@"followers"]];
            
            [items addObject:statsItem];
        }
        
        if (completionHandler) {
            // More not available with publicize
            completionHandler(items, nil, false, nil);
        }
    };
    
    AFHTTPRequestOperation *operation = [self requestOperationForURLString:[self urlForPublicize]
                                                                parameters:nil
                                                                   success:handler
                                                                   failure:[self failureForCompletionHandler:completionHandler]];
    
    return operation;
}


#pragma mark - Private convenience methods for building requests

- (AFHTTPRequestOperation *)requestOperationForURLString:(NSString *)url
                                              parameters:(NSDictionary *)parameters
                                                 success:(void (^)(AFHTTPRequestOperation *operation, id responseObject))success
                                                 failure:(void (^)(AFHTTPRequestOperation *operation, NSError *error))failure
{
    NSURLRequest *request = [self.manager.requestSerializer requestWithMethod:@"GET"
                                                                    URLString:url
                                                                   parameters:parameters
                                                                        error:nil];
    AFHTTPRequestOperation *operation = [self.manager HTTPRequestOperationWithRequest:request
                                                                              success:success
                                                                              failure:failure];
    
    return operation;
}


- (void(^)(AFHTTPRequestOperation *operation, NSError *error))failureForCompletionHandler:(StatsRemoteItemsCompletion)completionHandler
{
    return ^(AFHTTPRequestOperation *operation, NSError *error)
    {
        if (completionHandler) {
            completionHandler(nil, nil, false, error);
        }
    };
}


// TODO :: These could probably go into the operation methods since it's not really helpful any more
#pragma mark - Private methods for URL convenience


- (NSString *)urlForSummary
{
    return [NSString stringWithFormat:@"%@/summary/", self.statsPathPrefix];
}


- (NSString *)urlForVisits
{
    return [NSString stringWithFormat:@"%@/visits/", self.statsPathPrefix];
}


- (NSString *)urlForClicks
{
    return [NSString stringWithFormat:@"%@/clicks", self.statsPathPrefix];
}


- (NSString *)urlForCountryViews
{
    return [NSString stringWithFormat:@"%@/country-views", self.statsPathPrefix];
}


- (NSString *)urlForReferrers
{
    return [NSString stringWithFormat:@"%@/referrers/", self.statsPathPrefix];
}


- (NSString *)urlForPosts
{
    return [NSString stringWithFormat:@"%@/posts/", self.sitesPathPrefix];
}


- (NSString *)urlForTopPosts
{
    return [NSString stringWithFormat:@"%@/top-posts/", self.statsPathPrefix];
}


- (NSString *)urlForVideos
{
    return [NSString stringWithFormat:@"%@/video-plays/", self.statsPathPrefix];
}


- (NSString *)urlForAuthors
{
    return [NSString stringWithFormat:@"%@/top-authors/", self.statsPathPrefix];
}


- (NSString *)urlForSearchTerms
{
    return [NSString stringWithFormat:@"%@/search-terms/", self.statsPathPrefix];
}


- (NSString *)urlForComments
{
    return [NSString stringWithFormat:@"%@/comments/", self.statsPathPrefix];
}


- (NSString *)urlForTagsCategories
{
    return [NSString stringWithFormat:@"%@/tags/", self.statsPathPrefix];
}


- (NSString *)urlForFollowers
{
    return [NSString stringWithFormat:@"%@/followers/", self.statsPathPrefix];
}


- (NSString *)urlForPublicize
{
    return [NSString stringWithFormat:@"%@/publicize/", self.statsPathPrefix];
}


#pragma mark - Private convenience methods for data conversion


- (NSDate *)deviceLocalDateForString:(NSString *)dateString withPeriodUnit:(StatsPeriodUnit)unit
{
    switch (unit) {
        case StatsPeriodUnitDay:
        case StatsPeriodUnitMonth:
        case StatsPeriodUnitYear:
        {
            self.deviceDateFormatter.dateFormat = @"yyyy-MM-dd";
            break;
        }
        case StatsPeriodUnitWeek:
        {
            // Assumes format: yyyyWxxWxx first xx is month, second xx is first day of that week
            self.deviceDateFormatter.dateFormat = @"yyyy'W'MM'W'dd";
            break;
        }
    }
    
    NSDate *localDate = [self.deviceDateFormatter dateFromString:dateString];
    return localDate;
}


- (NSString *)deviceLocalStringForDate:(NSDate *)date
{
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
    formatter.dateFormat = @"yyyy-MM-dd";
    formatter.timeZone = [NSTimeZone localTimeZone];
    
    NSString *todayString = [formatter stringFromDate:date];
    return todayString;
}


- (NSString *)deviceLocalISOStringForDate:(NSDate *)date
{
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
    formatter.dateFormat = @"yyyy'-'MM'-'dd'T'HH':'mm':'ss";
    formatter.timeZone = [NSTimeZone localTimeZone];
    
    NSString *todayString = [formatter stringFromDate:date];
    return todayString;
}


- (StatsPeriodUnit)periodUnitForString:(NSString *)unitString
{
    if ([unitString isEqualToString:@"day"]) {
        return StatsPeriodUnitDay;
    } else if ([unitString isEqualToString:@"week"]) {
        return StatsPeriodUnitWeek;
    } else if ([unitString isEqualToString:@"month"]) {
        return StatsPeriodUnitMonth;
    } else if ([unitString isEqualToString:@"year"]) {
        return StatsPeriodUnitYear;
    }
    
    return StatsPeriodUnitDay;
}


- (NSString *)stringForPeriodUnit:(StatsPeriodUnit)unit
{
    switch (unit) {
        case StatsPeriodUnitDay:
            return @"day";
        case StatsPeriodUnitWeek:
            return @"week";
        case StatsPeriodUnitMonth:
            return @"month";
        case StatsPeriodUnitYear:
            return @"year";
    }
    
    return @"";
}


- (NSString *)nicePointNameForDate:(NSDate *)date forStatsPeriodUnit:(StatsPeriodUnit)unit {
    if (!date) {
        return @"";
    }
    
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    dateFormatter.locale = [NSLocale currentLocale];
    
    switch (unit) {
        case StatsPeriodUnitDay:
            dateFormatter.dateFormat = @"LLL d";
            break;
        case StatsPeriodUnitWeek:
            dateFormatter.dateFormat = @"LLL d";
            break;
        case StatsPeriodUnitMonth:
            dateFormatter.dateFormat = @"LLL";
            break;
        case StatsPeriodUnitYear:
            dateFormatter.dateFormat = @"yyyy";
            break;
    }
    
    NSString *niceName = [dateFormatter stringFromDate:date] ?: @"";

    return niceName;
}


- (NSString *)localizedStringForNumber:(NSNumber *)number
{
    return [self localizedStringForNumber:number withNumberStyle:NSNumberFormatterDecimalStyle];
}

- (NSString *)localizedStringForNumber:(NSNumber *)number withNumberStyle:(NSNumberFormatterStyle)numberStyle
{
    if (!number) {
        return nil;
    }
    
    self.deviceNumberFormatter.numberStyle = numberStyle;
    self.deviceNumberFormatter.maximumFractionDigits = 0;
    
    NSString *formattedNumber = [self.deviceNumberFormatter stringFromNumber:number];
    
    return formattedNumber;
}


- (NSString *)localizedStringForPeriodStartDate:(NSDate *)startDate endDate:(NSDate *)endDate
{
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.locale = [NSLocale currentLocale];
    formatter.dateFormat = @"MMM dd";
    formatter.timeZone = [NSTimeZone localTimeZone];
    
    NSString *startString = [formatter stringFromDate:startDate];
    NSString *endString = [formatter stringFromDate:endDate];
    
    return [NSString stringWithFormat:@"%@ - %@", startString, endString];
}


- (NSString *)localizedStringWithShortFormatForDate:(NSDate *)date
{
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.locale = [NSLocale currentLocale];
    formatter.dateFormat = @"EEE, MMM dd";
    formatter.timeZone = [NSTimeZone localTimeZone];
    
    NSString *dateString = [formatter stringFromDate:date];
    
    return dateString;
}


- (NSString *)localizedStringForMonthOrdinal:(NSUInteger)monthNumber
{
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.locale = [NSLocale currentLocale];
    
    return formatter.monthSymbols[monthNumber - 1];
}


- (NSDate *)calculateStartDateForPeriodUnit:(StatsPeriodUnit)unit withEndDate:(NSDate *)date
{
    NSCalendar *calendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
    
    if (unit == StatsPeriodUnitDay) {
        NSDateComponents *dateComponents = [calendar components:NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay fromDate:date];
        date = [calendar dateFromComponents:dateComponents];
        
        return date;
    } else if (unit == StatsPeriodUnitMonth) {
        NSDateComponents *dateComponents = [calendar components:NSCalendarUnitYear | NSCalendarUnitMonth fromDate:date];
        date = [calendar dateFromComponents:dateComponents];
        
        dateComponents = [NSDateComponents new];
        dateComponents.day = +1;
        dateComponents.month = -1;
        date = [calendar dateByAddingComponents:dateComponents toDate:date options:0];
        
        return date;
    } else if (unit == StatsPeriodUnitWeek) {
        // Weeks are Monday - Sunday
        NSDateComponents *dateComponents = [calendar components:NSCalendarUnitYear | NSCalendarUnitMonth fromDate:date];
        date = [calendar dateFromComponents:dateComponents];
        
        dateComponents = [NSDateComponents new];
        dateComponents.day = -6;
        date = [calendar dateByAddingComponents:dateComponents toDate:date options:0];
        
        return date;
    } else if (unit == StatsPeriodUnitYear) {
        NSDateComponents *dateComponents = [calendar components:NSCalendarUnitYear fromDate:date];
        date = [calendar dateFromComponents:dateComponents];
        
        dateComponents = [NSDateComponents new];
        dateComponents.day = +1;
        dateComponents.year = -1;
        date = [calendar dateByAddingComponents:dateComponents toDate:date options:0];
        
        return date;
    }
    
    return nil;
}


- (void)cancelAllRemoteOperations
{
    if (self.manager.operationQueue.operationCount == 0) {
        return;
    }
    
    DDLogVerbose(@"Canceling %@ operations...", @(self.manager.operationQueue.operationCount));
    [self.manager.operationQueue cancelAllOperations];
}


- (NSDictionary *)dictionaryFromResponse:(id)responseObject
{
    if ([responseObject isKindOfClass:[NSDictionary class]]) {
        return responseObject;
    }
    
    return nil;
}


@end
