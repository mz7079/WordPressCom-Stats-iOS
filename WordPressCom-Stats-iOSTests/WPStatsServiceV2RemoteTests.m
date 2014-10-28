#import <UIKit/UIKit.h>
#import <XCTest/XCTest.h>
#import <OHHTTPStubs/OHHTTPStubs.h>
#import <OCMock/OCMock.h>
#import "WPStatsServiceV2Remote.h"

@interface WPStatsServiceV2RemoteTests : XCTestCase

@property (nonatomic, strong) WPStatsServiceV2Remote *subject;

@end

@implementation WPStatsServiceV2RemoteTests

- (void)setUp {
    [super setUp];
    
    self.subject = [[WPStatsServiceV2Remote alloc] initWithOAuth2Token:@"token" siteId:@66592863 andSiteTimeZone:[NSTimeZone systemTimeZone]];
}

- (void)tearDown {
    [super tearDown];
    
    self.subject = nil;
}

- (void)testSummary {
    XCTestExpectation *expectation = [self expectationWithDescription:@"testFetchSummaryStats completion"];
    
    [OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
        return [[request.URL absoluteString] hasPrefix:@"https://public-api.wordpress.com/rest/v1.1/sites/66592863/stats/summary/"];
    } withStubResponse:^OHHTTPStubsResponse *(NSURLRequest *request) {
        return [OHHTTPStubsResponse responseWithFileAtPath:OHPathForFileInBundle(@"stats-v1.1-summary.json", nil) statusCode:200 headers:@{@"Content-Type" : @"application/json"}];
    }];
    
    [self.subject fetchSummaryStatsForTodayWithCompletionHandler:^(StatsSummary *summary) {
        XCTAssertNotNil(summary, @"summary should not be nil.");
        XCTAssertTrue([summary.views isEqualToNumber:@56]);
        XCTAssertTrue([summary.visitors isEqualToNumber:@44]);
        XCTAssertTrue([summary.likes isEqualToNumber:@1]);
        XCTAssertTrue([summary.reblogs isEqualToNumber:@2]);
        XCTAssertTrue([summary.comments isEqualToNumber:@3]);
        
        [expectation fulfill];
    } failureHandler:^(NSError *error) {
        XCTFail(@"Failure handler should not be called here.");
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:2.0 handler:nil];
}

@end
