//
//  MDKStringConverter.m
//  MarkdownKit
//
//  Created by Casey Marshall on 5/16/10.
//  Copyright 2010 Modal Domains. All rights reserved.
//
// Permission is hereby granted, free of charge, to any person obtaining a
// copy of this software and associated documentation files (the "Software"),
// to deal in the Software without restriction, including without limitation
// the rights to use, copy, modify, merge, publish, distribute, sublicense,
// and/or sell copies of the Software, and to permit persons to whom the
// Software is furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included
// in all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
// OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
// THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
// FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
// DEALINGS IN THE SOFTWARE.


#import "MDKStringConverter.h"



@interface MDKStringConverter(internals)

- (void) detabify: (NSMutableString *) str;
- (void) findHTMLBlockRangesForString:(NSString *)str plainRanges:(NSMutableArray *)plainRanges blockRanges:(NSMutableArray *)blockRanges;

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
    NSString *closeTag = [[@"<\\s*/\\s*" stringByAppendingString: blockTags]
                          stringByAppendingString: @"\\s*>"];
    
    for (NSString *line in [str componentsMatchedByRegex: @""])
    {
    }
}

/**
 * Finds all nested HTML blocks in `str`, placing ranges in `str` of "normal"
 * text in `plainRanges`, and ranges of HTML blocks in `blockRanges`.
 *
 * Does the work of _HashHTMLBlocks in Markdown.pl, but a different way.
 */
- (void) findHTMLBlockRangesForString: (NSString *) str
                          plainRanges: (NSMutableArray *) plainRanges
                          blockRanges: (NSMutableArray *) blockRanges
{
}

- (NSString *) doHeaders: (NSString *) text
{
    NSMutableString *str = [NSMutableString stringWithString: text];
    // Setext style headers.
    //
    //   Header 1
    //   ========
    //
    //   Header 2
    //   --------
    
    NSRange range = NSMakeRange(0, [str length]);
    while (range.location < [str length])
    {
        NSRange r = [str rangeOfRegex: @"^(.+?)[ \t]*\n=+[ \t]*\n+"
                              options: RKLMultiline
                              inRange: range
                              capture: 0
                                error: NULL];
        if (r.location == NSNotFound)
            break;
        
        NSArray *capture = [str captureComponentsMatchedByRegex: @"^(.+?)[ \t]*\n=+[ \t]*\n+"
                                                        options: RKLMultiline
                                                          range: r
                                                          error: NULL];
        
        [str replaceCharactersInRange: r
                           withString: [[@"<h1>" stringByAppendingString:
                                         [self runSpanGamut: [capture objectAtIndex: 1]]]
                                        stringByAppendingString: @"</h1>"]];
        
        range.location = r.location;
        range.length = [str length] - r.location;
    }
    
    range = NSMakeRange(0, [str length]);
    while (range.location < [str length])
    {
        NSRange r = [str rangeOfRegex: @"^(.+?)[ \t]*\n-+[ \t]*\n+"
                              options: RKLMultiline
                              inRange: range
                              capture: 0
                                error: NULL];
        if (r.location == NSNotFound)
            break;
        
        NSArray *capture = [str captureComponentsMatchedByRegex: @"^(.+?)[ \t]*\n-+[ \t]*\n+"
                                                        options: RKLMultiline
                                                          range: r
                                                          error: NULL];
        
        [str replaceCharactersInRange: r
                           withString: [[@"<h2>" stringByAppendingString:
                                         [self runSpanGamut: [capture objectAtIndex: 1]]]
                                        stringByAppendingString: @"</h2>"]];
        
        range.location = r.location;
        range.length = [str length] - r.location;
    }
    
    // atx-style headers
    //	# Header 1
    //	## Header 2
    //	## Header 2 with closing hashes ##
    //	...
    //	###### Header 6

    NSString *regex = @"^(#{1,6})[ \t]*(.+?)#*\n+";
    range = NSMakeRange(0, [str length]);
    while (range.location < [str length])
    {
        NSRange r = [str rangeOfRegex: regex
                              options: RKLMultiline
                              inRange: range
                              capture: 0
                                error: NULL];
        if (r.location == NSNotFound)
            break;
        
        NSArray *capture = [str captureComponentsMatchedByRegex: regex
                                                        options: RKLMultiline
                                                          range: r
                                                          error: NULL];
        int len = [[capture objectAtIndex: 1] length];
        [str replaceCharactersInRange:r
                           withString: [NSString stringWithFormat: @"<h%d>%@</h%d>",
                                        len, [self runSpanGamut: [capture objectAtIndex: 2]],
                                        len]];
        range.location = r.location;
        range.length = [str length] - r.location;
    }
    
    return str;
}
    
- (void) runBlockGamut: (NSMutableString *) str
{
    // [self doHeaders: str];
    
    // Horizontal rules:
    
    [str replaceOccurrencesOfRegex: @"^[ ]{0,2}([ ]?\\*[ ]?){3,}[\n\t]*$"
                        withString: [[@"\n<hr" stringByAppendingString: self.emptyElementSuffix]
                                     stringByAppendingString: @"\n"]];
    [str replaceOccurrencesOfRegex: @"^[ ]{0,2}([ ]?\\*[ ]?){3,}[\n\t]*$"
                        withString: [[@"\n<hr" stringByAppendingString: self.emptyElementSuffix]
                                     stringByAppendingString: @"\n"]];
    [str replaceOccurrencesOfRegex: @"^[ ]{0,2}([ ]?\\*[ ]?){3,}[\n\t]*$"
                        withString: [[@"\n<hr" stringByAppendingString: self.emptyElementSuffix]
                                     stringByAppendingString: @"\n"]];
}

- (NSString *) runSpanGamut: (NSString *) str
{
    return str; // TODO
}

@end


@implementation MDKStringConverter

@synthesize tabWidth;
@synthesize emptyElementSuffix;

- (id) init
{
    if (self = [super init])
    {
        self.tabWidth = 4;
        self.emptyElementSuffix = @">";
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
