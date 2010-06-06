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
#import <CommonCrypto/CommonDigest.h>

@interface NSString(MD5)

- (NSData *) dataWithMD5UsingEncoding: (NSStringEncoding) encoding;
- (NSString *) stringWithMD5UsingEncoding: (NSStringEncoding) encoding;

@end

@implementation NSString(MD5)

- (NSData *) dataWithMD5UsingEncoding: (NSStringEncoding) encoding
{
    NSData *d = [self dataUsingEncoding: encoding];
    unsigned char md5[16];
    CC_MD5([d bytes], [d length], md5);
    return [NSData dataWithBytes: md5 length: 16];
}

- (NSString *) stringWithMD5UsingEncoding: (NSStringEncoding) encoding
{
    NSData *md5 = [self dataWithMD5UsingEncoding: encoding];
    unsigned char *md5buf = (unsigned char *) [md5 bytes];
    return [NSString stringWithFormat: @"%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x",
            md5buf[ 0], md5buf[ 1], md5buf[ 2], md5buf[ 3],
            md5buf[ 4], md5buf[ 5], md5buf[ 6], md5buf[ 7],
            md5buf[ 8], md5buf[ 9], md5buf[10], md5buf[11],
            md5buf[12], md5buf[13], md5buf[14], md5buf[15]];
}

@end


@interface MDKStringConverter(internals)

- (NSString *) detabify: (NSString *) str;
- (NSString *) hashHTMLBlocksForString:(NSString *)text;
- (NSString *) doHeaders:(NSString *)text;
- (NSString *) runBlockGamut:(NSString *)text;
- (NSString *) runSpanGamut:(NSString *)text;
- (NSString *) stripLinkDefinitions: (NSString *) text;
- (NSString *) unescapeSpecialChars: (NSString *) text;
- (NSString *) doLists: (NSString *) text;
- (NSString *) doCodeBlocks: (NSString *) text;
- (NSString *) doBlockQuotes: (NSString *) text;
- (NSString *) formParagraphs: (NSString *) text;
- (NSString *) doCodeSpans: (NSString *) text;
- (NSString *) escapeSpecialCharsWithinTagAttributes: (NSString *) text;
- (NSString *) encodeBackslashEscapes: (NSString *) text;
- (NSString *) doImages: (NSString *) text;
- (NSString *) doAnchors: (NSString *) text;
- (NSString *) doAutoLinks: (NSString *) text;
- (NSString *) encodeAmpsAndAngles: (NSString *) text;
- (NSString *) doItalicsAndBold: (NSString *) text;

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

- (NSString *) detabify: (NSString *) text
{
    NSLog(@"detabify: %@", [text substringToIndex: 32 < [text length] ? 32 : [text length]]);
    NSMutableString *str = [NSMutableString stringWithString: text];
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
            column = 0;
        else
            column++;
    }
    return str;
}

- (NSString *) hashHTMLBlocksForString: (NSString *) text
{
    NSLog(@"hashHTMLBlocksForString: %@", [text substringToIndex: 32<[text length] ? 32 : [text length]]);    
    text = [text stringByReplacingOccurrencesOfRegex: @"\\n"
                                          withString: @"\n\n"];

    // First, look for nested blocks, e.g.:
	//   <div>
	//     <div>
	//     tags for inner block must be indented.
	//     </div>
	//   </div>
	//
	// The outermost tags must start at the left margin for this to match, and
	// the inner nested divs must be indented.
	// We need to do this before the next, more liberal match, because the next
	// match will start at the first `<div>` and stop at the first `</div>`.
    
	// attacklab: This regex can be expensive when it fails.
	/*
     var text = text.replace(/
     (						// save in $1
     ^					// start of line  (with /m)
     <($block_tags_a)	// start tag = $2
     \b					// word break
     // attacklab: hack around khtml/pcre bug...
     [^\r]*?\n			// any number of lines, minimally matching
     </\2>				// the matching end tag
     [ \t]*				// trailing spaces/tabs
     (?=\n+)				// followed by a newline
     )						// attacklab: there are sentinel newlines at end of document
     /gm,function(){...}};
     */    
    while (YES)
    {
        NSRange r = [text rangeOfRegex: @"^(<(p|div|h[1-6]|blockquote|pre|table|dl|ol|ul|script|noscript|form|fieldset|iframe|math|ins|del)\\b[^\\r]*?\\n<\\/\\2>[ \t]*(?=\\n+))"
                               options: RKLMultiline
                               inRange: NSMakeRange(0, [text length])
                               capture: 0
                                 error: NULL];
        if (r.location == NSNotFound)
            break;
        
        NSString *hash = [[text substringWithRange: r] stringWithMD5UsingEncoding: NSUTF8StringEncoding];
        text = [text stringByReplacingCharactersInRange: r
                                             withString: hash];        
    }
    
	//
	// Now match more liberally, simply from `\n<tag>` to `</tag>\n`
	//
    
	/*
     var text = text.replace(/
     (						// save in $1
     ^					// start of line  (with /m)
     <($block_tags_b)	// start tag = $2
     \b					// word break
     // attacklab: hack around khtml/pcre bug...
     [^\r]*?				// any number of lines, minimally matching
     .*</\2>				// the matching end tag
     [ \t]*				// trailing spaces/tabs
     (?=\n+)				// followed by a newline
     )						// attacklab: there are sentinel newlines at end of document
     /gm,function(){...}};
     */
    while (YES)
    {
        NSRange r = [text rangeOfRegex: @"^(<(p|div|h[1-6]|blockquote|pre|table|dl|ol|ul|script|noscript|form|fieldset|iframe|math)\\b[^\\r]*?.*<\\/\\2>[ \t]*(?=\\n+)\\n)"
                               options: RKLMultiline
                               inRange: NSMakeRange(0, [text length])
                               capture: 0
                                 error: NULL];
        if (r.location == NSNotFound)
            break;
        
        NSString *hash = [[text substringWithRange: r] stringWithMD5UsingEncoding: NSUTF8StringEncoding];
        text = [text stringByReplacingCharactersInRange: r
                                             withString: hash];
    }
    
    // Special case just for <hr />. It was easier to make a special case than
	// to make the other regex more complicated.  
    
	/*
     text = text.replace(/
     (						// save in $1
     \n\n				// Starting after a blank line
     [ ]{0,3}
     (<(hr)				// start tag = $2
     \b					// word break
     ([^<>])*?			// 
     \/?>)				// the matching end tag
     [ \t]*
     (?=\n{2,})			// followed by a blank line
     )
     /g,hashElement);
     */
    
    while (YES)
    {
        NSRange r = [text rangeOfRegex: @"(\\n[ ]{0,3}(<(hr)\\b([^<>])*?\\/?>)[ \\t]*(?=\\n{2,}))"
                               options: RKLNoOptions
                               inRange: NSMakeRange(0, [text length])
                               capture: 0
                                 error: NULL];
        if (r.location == NSNotFound)
            break;

        NSString *hash = [[text substringWithRange: r] stringWithMD5UsingEncoding: NSUTF8StringEncoding];
        text = [text stringByReplacingCharactersInRange: r
                                             withString: hash];
    }

    // Special case for standalone HTML comments:
    
	/*
     text = text.replace(/
     (						// save in $1
     \n\n				// Starting after a blank line
     [ ]{0,3}			// attacklab: g_tab_width - 1
     <!
     (--[^\r]*?--\s*)+
     >
     [ \t]*
     (?=\n{2,})			// followed by a blank line
     )
     /g,hashElement);
     */
    while (YES)
    {
        NSRange r = [text rangeOfRegex: @"(\\n\\n[ ]{0,3}<!(--[^\\r]*?--\\s*)+>[ \\t]*(?=\\n{2,}))"
                               options: RKLNoOptions
                               inRange: NSMakeRange(0, [text length])
                               capture: 0
                                 error: NULL];
        if (r.location == NSNotFound)
            break;
        
        NSString *hash = [[text substringWithRange: r] stringWithMD5UsingEncoding: NSUTF8StringEncoding];
        text = [text stringByReplacingCharactersInRange: r
                                             withString: hash];
    }

    // PHP and ASP-style processor instructions (<?...?> and <%...%>)
    
	/*
     text = text.replace(/
     (?:
     \n\n				// Starting after a blank line
     )
     (						// save in $1
     [ ]{0,3}			// attacklab: g_tab_width - 1
     (?:
     <([?%])			// $2
     [^\r]*?
     \2>
     )
     [ \t]*
     (?=\n{2,})			// followed by a blank line
     )
     /g,hashElement);
     */
    while (YES)
    {
        NSRange r = [text rangeOfRegex: @"(?:\\n\\n)([ ]{0,3}(?:<([?%])[^\\r]*?\\2>)[ \\t]*(?=\\n{2,}))"
                               options: RKLNoOptions
                               inRange: NSMakeRange(0, [text length])
                               capture: 0
                                 error: NULL];
        if (r.location == NSNotFound)
            break;

        NSString *hash = [[text substringWithRange: r] stringWithMD5UsingEncoding: NSUTF8StringEncoding];
        text = [text stringByReplacingCharactersInRange: r
                                             withString: hash];
    }
    
    return [text stringByReplacingOccurrencesOfRegex: @"\\n\\n"
                                          withString: @"\n"];
}

- (NSString *) doHeaders: (NSString *) text
{
    NSLog(@"doHeaders: %@", [text substringToIndex: 32 < [text length] ? 32 : [text length]]);
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
        
        NSLog(@"Header match region: %@", [str substringWithRange: r]);
        NSArray *capture = [str captureComponentsMatchedByRegex: regex
                                                        options: RKLMultiline
                                                          range: r
                                                          error: NULL];
        int len = [[capture objectAtIndex: 1] length];
        NSLog(@"header capture: %@", capture);
        [str replaceCharactersInRange: r
                           withString: [NSString stringWithFormat: @"<h%d>%@</h%d>",
                                        len, [self runSpanGamut: [capture objectAtIndex: 2]],
                                        len]];
        range.location = r.location + len;
        range.length = [str length] - range.location;
    }
    
    return str;
}
    
- (NSString *) runBlockGamut: (NSString *) text
{
    NSLog(@"runBlockGamut: %@", [text substringToIndex: 32 < [text length] ? 32 : [text length]]);
    
    // Horizontal rules:
    
    text = [text stringByReplacingOccurrencesOfRegex: @"^[ ]{0,2}([ ]?\\*[ ]?){3,}[\n\t]*$"
                                          withString: [[@"\n<hr" stringByAppendingString: self.emptyElementSuffix]
                                                       stringByAppendingString: @"\n"]];
    text = [text stringByReplacingOccurrencesOfRegex: @"^[ ]{0,2}([ ]?\\*[ ]?){3,}[\n\t]*$"
                                          withString: [[@"\n<hr" stringByAppendingString: self.emptyElementSuffix]
                                                       stringByAppendingString: @"\n"]];
    text = [text stringByReplacingOccurrencesOfRegex: @"^[ ]{0,2}([ ]?\\*[ ]?){3,}[\n\t]*$"
                                          withString: [[@"\n<hr" stringByAppendingString: self.emptyElementSuffix]
                                                       stringByAppendingString: @"\n"]];
    text = [self doLists: text];
    text = [self doCodeBlocks: text];
    text = [self doBlockQuotes: text];
    
    text = [self hashHTMLBlocksForString: text];
    text = [self formParagraphs: text];
    
    return text;
}

- (NSString *) runSpanGamut: (NSString *) text
{
    NSLog(@"runSpanGamut: %@", [text substringToIndex: 32 < [text length] ? 32 : [text length]]);

    text = [self doCodeSpans: text];
    text = [self escapeSpecialCharsWithinTagAttributes: text];
    text = [self encodeBackslashEscapes: text];
    text = [self doImages: text];
    text = [self doAnchors: text];
    text = [self doAutoLinks: text];
    text = [self encodeAmpsAndAngles: text];
    text = [self doItalicsAndBold: text];
    
    // Hard breaks.
    text = [text stringByReplacingOccurrencesOfRegex: @"^  +"
                                          withString: [@"<br" stringByAppendingString: self.emptyElementSuffix]];
    
    return text;
}

- (NSString *) stripLinkDefinitions: (NSString *) text
{
    NSLog(@"stripLinkDefinitions: %@", [text substringToIndex: 32 < [text length] ? 32 : [text length]]);
    return text; // TODO
}

- (NSString *) unescapeSpecialChars: (NSString *) text;
{
    NSLog(@"unescapeSpecialChars: %@", [text substringToIndex: 32 < [text length] ? 32 : [text length]]);
    return text; // TODO
}

- (NSString *) doLists: (NSString *) text
{
    return text;
}

- (NSString *) doCodeBlocks: (NSString *) text
{
    return text;
}

- (NSString *) doBlockQuotes: (NSString *) text
{
    return text;
}

- (NSString *) formParagraphs: (NSString *) text
{
    return text;
}

- (NSString *) doCodeSpans: (NSString *) text
{
    return text; // TODO
}

- (NSString *) escapeSpecialCharsWithinTagAttributes: (NSString *) text
{
    return text; // TODO
}

- (NSString *) encodeBackslashEscapes: (NSString *) text
{
    return text; // TODO
}

- (NSString *) doImages: (NSString *) text
{
    return text; // TODO
}

- (NSString *) doAnchors: (NSString *) text
{
    return text; // TODO
}

- (NSString *) doAutoLinks: (NSString *) text
{
    text = [text stringByReplacingOccurrencesOfRegex: @"<((https?|ftp|dict):[^'\">\\s]+)>"
                                          withString: @"<a href=\"$1\">$1</a>"
                                             options: RKLCaseless
                                               range: NSMakeRange(0, [text length])
                                               error: NULL];
    
    while (YES)
    {
        NSRange r = [text rangeOfRegex: @"<(?:mailto:)?([-.\\w]+\\@[-a-z0-9]+(\\.[-a-z0-9]+)*\\.[a-z]+)"
                               options: RKLCaseless
                               inRange: NSMakeRange(0, [text length])
                               capture: 0
                                 error: NULL];
        if (r.location == NSNotFound)
            break;
        
        NSRange r2 = [text rangeOfRegex: @"<(?:mailto:)?([-.\\w]+\\@[-a-z0-9]+(\\.[-a-z0-9]+)*\\.[a-z]+)"
                                options: RKLCaseless
                                inRange: NSMakeRange(0, [text length])
                                capture: 1
                                  error: NULL]; 
        
        NSString *addr = [text substringWithRange: r2];
        NSMutableString *encmailto = [NSMutableString stringWithCapacity: 10];
        NSMutableString *encaddr = [NSMutableString stringWithCapacity: [addr length]];
        
        srandom(time(NULL));
        
        for (int i = 0; i < [@"mailto" length]; i++)
        {
            unichar ch = [@"mailto" characterAtIndex: i];
            int r = random();
            if (r % 10 == 0)
                [encmailto appendString: [NSString stringWithCharacters: &ch
                                                               length: 1]];
            else if (r % 2 == 0)
                [encmailto appendFormat: @"&#%d", (int) ch];
            else
                [encmailto appendFormat: @"&#x%x", (int) ch];            
        }
        
        for (int i = 0; i < [addr length]; i++)
        {
            unichar ch = [addr characterAtIndex: i];
            int r = random();
            if (ch == '@')
            {
                if (r % 2 == 0)
                    [encaddr appendFormat: @"&#%d", (int) ch];
                else
                    [encaddr appendFormat: @"&#x%x", (int) ch];
            }
            else
            {
                if (r % 10 == 0)
                    [encaddr appendString: [NSString stringWithCharacters: &ch
                                                                   length: 1]];
                else if (r % 2 == 0)
                    [encaddr appendFormat: @"&#%d", (int) ch];
                else
                    [encaddr appendFormat: @"&#x%x", (int) ch];
            }
        }
        
        text = [text stringByReplacingCharactersInRange: r
                                             withString: [NSString stringWithFormat: @"<a href=\"%@:%@\">%@</a>",
                                                          encmailto, encaddr, encaddr]];
    }

    return text;
}

- (NSString *) encodeAmpsAndAngles: (NSString *) text
{
    text = [text stringByReplacingOccurrencesOfRegex: @"&(?!#?[xX]?(?:[0-9a-fA-F]+|\\w+);)"
                                          withString: @"&amp;"];
    text = [text stringByReplacingOccurrencesOfRegex: @"<(?![a-z\\/?\\$!])"
                                          withString: @"&lt;"];
    return text;
}

- (NSString *) doItalicsAndBold: (NSString *) text
{
    text = [text stringByReplacingOccurrencesOfRegex: @"(\\*\\*|__)(?=\\S)([^\\r]*?\\S[*_]*)\\1"
                                          withString: @"<strong>$2</strong>"];
    text = [text stringByReplacingOccurrencesOfRegex: @"(\\*|_)(?=\\S)([^\\r]*?\\S)\\1"
                                          withString: @"<em>$2</em>"];
    return text; // TODO
}

@end


@implementation MDKStringConverter

@synthesize emptyElementSuffix;

- (NSUInteger) tabWidth
{
    return tabWidth;
}

- (void) setTabWidth:(NSUInteger) value
{
    if (value < 2)
        [NSException raise: @"MDKInvalidTabWidth"
                    format: @"tab width should be >= 2"];
    tabWidth = value;
}

- (id) init
{
    if (self = [super init])
    {
        self.tabWidth = 4;
        self.emptyElementSuffix = @" />";
        
        blockHash = [[NSMutableDictionary alloc] init];
        urlHash = [[NSMutableDictionary alloc] init];
        titlesHash = [[NSMutableDictionary alloc] init];
    }
    return self;
}

- (NSString *) convertMarkdownStringToHTML:(NSString *)markdown
{
    [blockHash removeAllObjects];
    [urlHash removeAllObjects];
    [titlesHash removeAllObjects];

    NSMutableString *work = [[NSMutableString alloc] initWithString: markdown];
    [work replaceOccurrencesOfString: @"\r\n"
                          withString: @"\n"
                             options: NSLiteralSearch
                               range: NSMakeRange(0, [work length])];
    [work replaceOccurrencesOfString: @"\r"
                          withString: @"\n"
                             options: NSLiteralSearch
                               range: NSMakeRange(0, [work length])];
    [work appendString: @"\n\n"];
    NSMutableString *work2 = [[NSMutableString alloc] initWithString: [self detabify: work]];
    [work release];
    [work2 replaceOccurrencesOfRegex: @"^[ \t]+$"
                          withString: @""];
    NSString *text = [self hashHTMLBlocksForString: work2];
    [work2 release];
    text = [self stripLinkDefinitions: text];
    text = [self runBlockGamut: text];
    text = [self unescapeSpecialChars: text];
    return [text stringByAppendingString: @"\n"];
}

@end
