//
//  MDKStringConverter.m
//  MarkdownKit
//
//  Created by Casey Marshall on 5/16/10.
//  Copyright 2010 Modal Domains. All rights reserved.
//

#import "MDKStringConverter.h"



@interface MDKStringConverter(internals)

- (void) detabify: (NSMutableString *) str;

@end

@implementation MDKStringConverter(internals)

static NSString *
nspaces(NSUInteger n)
{
    NSMutableString *s = [NSMutableString stringWithCapacity: n];
    for (int i = 0; i < n; i++)
        [s appendString: @" "];
    return s;
}

- (void) detabify: (NSMutableString *) str
{
    int column = 0;
    for (int i = 0; i < [str length]; i++)
    {
        if ([str characterAtIndex: i] == (unichar) '\t')
        {
            int len = self.tabWidth - column % self.tabWidth;
            [str replaceCharactersInRange: NSMakeRange(i, 1)
                               withString: nspaces(len)];
            column++;
        }
        else if ([str characterAtIndex: i] == (unichar) '\n')
        {
            column = 0;
        }
        else
            column++;
    }
}

- (void) hashHTMLBlocksForString: (NSMutableString *) str
                      dictionary: (NSMutableDictionary *) dict
{
    NSString *blockTags = @"(?:p|div|h[1-6]|blockquote|pre|table|dl|ol|ul|script|noscript|form|fieldset|iframe|math|ins|del)";
    NSString *tagAttrs = @"(?:\\s+[\\w.:_-]+\\s*=\\s*(?:\".+?\"|'.+?'))*";
    NSString *emptyTag = [[@"<\\w+" stringByAppendingString: tagAttrs] stringByAppendingString: @"\\s*/>"];
    NSString *openTag = [[[@"<" stringByAppendingString: blockTags]
                          stringByAppendingString: tagAttrs]
                         stringByAppendingString: @"\\s*>"];
    
    // TODO
}

@end


@implementation MDKStringConverter

@synthesize tabWidth;

- (id) init
{
    if (self = [super init])
    {
        tabWidth = 4;
    }
    return self;
}

- (NSString *) convertMarkdownStringToHTML:(NSString *)markdown
{
    NSMutableDictionary *htmlBlocks = [NSMutableDictionary dictionary];
    
    NSMutableString *work = [NSMutableString stringWithString: markdown];
    [work replaceOccurrencesOfString: @"\r\n"
                          withString: @"\n"
                             options: NSLiteralSearch
                               range: NSMakeRange(0, [work length])];
    [work replaceOccurrencesOfString: @"\r"
                          withString: @"\n"
                             options: NSLiteralSearch
                               range: NSMakeRange(0, [work length])];
    [work appendString: @"\n\n"];
    [self detabify: work];
    [work replaceOccurrencesOfRegex: @"^[ \t]+$"
                         withString: @""];
    [self hashHTMLBlocksForString: work
                       dictionary: htmlBlocks];
    // TODO
    return [NSString stringWithString: work];
}

@end
