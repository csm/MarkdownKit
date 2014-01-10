//
//  MarkdownKit_Tests.m
//  MarkdownKit Tests
//
//  Created by Casey Marshall on 1/9/14.
//
//

#import <XCTest/XCTest.h>
#import <MarkdownKit/MarkdownKit.h>

@interface MarkdownKit_Tests : XCTestCase

@end

@implementation MarkdownKit_Tests

- (void)setUp
{
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown
{
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)test1
{
    NSString *html = [MDKMarkdown htmlStringForMarkdownString: @"This is a _simple_ **markdown** `string`."
                                                        flags: 0];
    XCTAssertNotNil(html, @"result should be non nil");
    NSLog(@"html string: %@", html);
}

@end
