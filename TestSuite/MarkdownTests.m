//
//  MarkdownTests.m
//  MarkdownKit
//
//  Created by Casey Marshall on 6/5/10.
//  Copyright 2010 Modal Domains. All rights reserved.
//

#import "MarkdownTests.h"
#import "MDKStringConverter.h"

@implementation MarkdownTests

- (void) testMarkdown
{
    NSBundle *bundle = [NSBundle bundleForClass: [MarkdownTests class]];
    STAssertNotNil(bundle, @"can't find my bundle");
    
    NSFileManager *fm = [NSFileManager defaultManager];
    NSError *error = nil;
    NSArray *contents = [fm contentsOfDirectoryAtPath: [bundle resourcePath]
                                                error: &error];
    STAssertNotNil(contents, @"loading %@: %@", [bundle resourcePath], error);
    
    MDKStringConverter *conv = [[MDKStringConverter alloc] init];
    
    for (int i = 0; i < [contents count]; i++)
    {
        NSString *textPath = [contents objectAtIndex: i];
        if ([textPath hasSuffix: @".text"])
        {
            NSString *htmlPath = [textPath stringByReplacingOccurrencesOfRegex: @"\\.text$"
                                                                    withString: @".html"];
            
            textPath = [[bundle resourcePath] stringByAppendingPathComponent: textPath];
            htmlPath = [[bundle resourcePath] stringByAppendingPathComponent: htmlPath];
            
            NSString *src = [NSString stringWithContentsOfFile: textPath
                                                      encoding: NSUTF8StringEncoding
                                                         error: &error];
            STAssertNotNil(src, @"loading path: %@ -- %@", textPath, error);
            NSString *s1 = [conv convertMarkdownStringToHTML: src];
            NSString *s2 = [NSString stringWithContentsOfFile: htmlPath
                                                     encoding: NSUTF8StringEncoding
                                                        error: &error];
            STAssertNotNil(s2, @"loading path; %@ -- %@", htmlPath, error);
            
            BOOL areEqual = [s1 isEqual: s2];
            if (!areEqual)
            {
                NSLog(@"failure -- output differs A>>%@<<A B>>%@<<B",
                      s1, s2);
            }
            
            STAssertTrue(areEqual, @"output differs for test %@", [contents objectAtIndex: i]);
        }
    }
    [conv release];
}

@end
