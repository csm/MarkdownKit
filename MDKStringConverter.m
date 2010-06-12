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

//#define VERY_VERBOSE 1

static NSString *escapeCharacters(NSString *text, NSString *charsToEscape, BOOL afterBackslash);

#if VERY_VERBOSE

static void
menter(NSString *method, NSString *format, ...)
{
    va_list args;
    va_start(args, format);
    NSString *msg = [[[NSString alloc] initWithFormat: format arguments: args] autorelease];
    NSLog(@"--> %@ %@", method, msg);
    va_end(args);
}

static void
mexit(NSString *method, NSString *format, ...)
{
    va_list args;
    va_start(args, format);
    NSString *msg = [[[NSString alloc] initWithFormat: format arguments: args] autorelease];
    NSLog(@"<-- %@ %@", method, msg);
    va_end(args);
}

#else
#define menter(x,y,...)
#define mexit(x,y,...)
#endif

@interface NSString(MD5)

- (NSData *) dataWithMD5UsingEncoding: (NSStringEncoding) encoding;
- (NSString *) stringWithMD5UsingEncoding: (NSStringEncoding) encoding;

- (NSString *) join: (NSArray *) array;

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

- (NSString *) join: (NSArray *) array
{
    NSMutableString *ret = [NSMutableString stringWithCapacity: 64];
    int len = [array count];
    for (int i = 0; i < len; i++)
    {
        [ret appendFormat: @"%@", [array objectAtIndex: i]];
        if (i < len - 1)
            [ret appendString: self];
    }
    return ret;
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
- (NSString *) writeImageTag: (NSArray *) matches;
- (NSString *) doImages: (NSString *) text;
- (NSString *) doAnchors: (NSString *) text;
- (NSString *) doAutoLinks: (NSString *) text;
- (NSString *) encodeAmpsAndAngles: (NSString *) text;
- (NSString *) doItalicsAndBold: (NSString *) text;
- (NSString *) processListItems: (NSString *) text;
- (NSString *) outdent: (NSString *) text;
- (NSString *) encodeCode: (NSString *) text;

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
    menter(@"detabify", @"%@", text);
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
    mexit(@"detabify", @"%@", str);
    return str;
}

- (NSString *) outdent: (NSString *) text
{
    menter(@"outdent", @"%@", text);
    NSString *regex = [NSString stringWithFormat: @"^(\t|[ ]{1,%d})", self.tabWidth];
    text = [text stringByReplacingOccurrencesOfRegex: regex
                                          withString: @""];
    mexit(@"outdent", @"%@", text);
    return text;
}

- (NSString *) hashHTMLBlocksForString: (NSString *) text
{
    menter(@"hashHTMLBlocksForString", @"%@", text);
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
        
        NSString *str = [text substringWithRange: r];
        NSString *hash = [str stringWithMD5UsingEncoding: NSUTF8StringEncoding];
        NSLog(@"hashing %@ -> %@", hash, str);
        [blockHash setObject: [str stringByReplacingOccurrencesOfRegex: @"\\n\\n"
                                                            withString: @"\n"]
                      forKey: hash];
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
        
        NSString *str = [text substringWithRange: r];
        NSString *hash = [str stringWithMD5UsingEncoding: NSUTF8StringEncoding];
        NSLog(@"hashing 1 %@ -> %@", hash, str);
        [blockHash setObject: [str stringByReplacingOccurrencesOfRegex: @"\\n\\n"
                                                            withString: @"\n"]
                      forKey: hash];
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

        NSString *str = [text substringWithRange: r];
        NSString *hash = [str stringWithMD5UsingEncoding: NSUTF8StringEncoding];
        NSLog(@"hashing 2 %@ -> %@", hash, str);
        [blockHash setObject: [str stringByReplacingOccurrencesOfRegex: @"\\n\\n"
                                                            withString: @"\n"]
                      forKey: hash];
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
        
        NSString *str = [text substringWithRange: r];
        NSString *hash = [str stringWithMD5UsingEncoding: NSUTF8StringEncoding];
        [blockHash setObject: str
                      forKey: hash];
        NSLog(@"hashing 3 %@ -> %@", hash, str);
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

        NSString *str = [text substringWithRange: r];
        NSString *hash = [str stringWithMD5UsingEncoding: NSUTF8StringEncoding];
        [blockHash setObject: [str stringByReplacingOccurrencesOfRegex: @"\\n\\n"
                                                            withString: @"\n"]
                      forKey: hash];
        text = [text stringByReplacingCharactersInRange: r
                                             withString: hash];
    }
    
    text = [text stringByReplacingOccurrencesOfRegex: @"\\n\\n"
                                          withString: @"\n"];
    mexit(@"hashHTMLBlocksForString", @"%@", text);
    return text;
}

- (NSString *) doHeaders: (NSString *) text
{
    menter(@"doHeaders", @"%@", text);
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
    
    mexit(@"doHeaders", @"%@", str);
    
    return str;
}
    
- (NSString *) runBlockGamut: (NSString *) text
{
    menter(@"runBlockGamut", @"%@", text);
    
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
    
    mexit(@"runBlockGamut", @"%@", text);
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
    menter(@"stripLinkDefinitions", @"%@", text);
    NSRange range = NSMakeRange(0, [text length]);
    while (range.location < [text length])
    {
        NSRange r = [text rangeOfRegex: @"^[ ]{0,3}\\[(.+)\\]:[ \\t]*\\n?[ \\t]*<?(\\S+?)>?[ \\t]*\\n?[ \\t]*(?:(\\n*)[\"(](.+?)[\")][ \\t]*)?(?:\\n+|\\Z)"
                               options: RKLMultiline
                               inRange: range
                               capture: 0
                                 error: NULL];
        
        if (r.location == NSNotFound)
            break;
        
        NSArray *a = [text arrayOfCaptureComponentsMatchedByRegex: @"^[ ]{0,3}\\[(.+)\\]:[ \\t]*\\n?[ \\t]*<?(\\S+?)>?[ \\t]*\\n?[ \\t]*(?:(\\n*)[\"(](.+?)[\")][ \\t]*)?(?:\\n+|\\Z)"
                                                          options: RKLMultiline
                                                            range: r
                                                            error: NULL];
        a = [a objectAtIndex: 0];
        
        NSString *m1 = [[a objectAtIndex: 1] lowercaseString];
        NSString *m2 = [a objectAtIndex: 2];
        [urlHash setObject: [self encodeAmpsAndAngles: m2]
                    forKey: m1];
        NSString *m3 = [a objectAtIndex: 3];
        NSString *m4 = [a objectAtIndex: 4];
        
        if ([m3 length] > 0)
        {
            NSString *rep = [m3 stringByAppendingString: m4];
            text = [text stringByReplacingCharactersInRange: r
                                                 withString: rep];
            range.location = r.location + [rep length];
        }
        else
        {
            if ([m4 length] > 0)
            {
                [titlesHash setObject: [m4 stringByReplacingOccurrencesOfString: @"\""
                                                                     withString: @"&quot"]
                               forKey: m1];
            }
            
            text = [text stringByReplacingCharactersInRange: r
                                                 withString: @""];
            range.location = r.location;
        }
        range.length = [text length] - range.location;
    }

    mexit(@"stripLinkDefinitions", @"%@", text);
    return text;
}

- (NSString *) unescapeSpecialChars: (NSString *) text;
{
    NSRange range = NSMakeRange(0, [text length]);
    while (range.location < [text length])
    {
        NSRange r = [text rangeOfRegex: @"~E(\\d+)E"
                               inRange: range];
        
        if (r.location == NSNotFound)
            break;
        
        NSRange r2 = [text rangeOfRegex: @"~E(\\d+)E"
                                options: RKLNoOptions
                                inRange: range
                                capture: 1
                                  error: NULL];
        text = [text stringByReplacingCharactersInRange: r
                                             withString: [NSString stringWithFormat: @"%C", (unichar) [[text substringWithRange: r2] intValue]]];
        range.location = r.location;
        range.length = [text length] - range.location;
    }
    
    return text;
}

- (NSString *) processListItems: (NSString *) text
{
    listLevel++;
    text = [text stringByReplacingOccurrencesOfRegex: @"\\n{2,}\\z"
                                          withString: @"\n"];
    
    NSString *regex = @"(\\n)?(^[ \\t]*)([*+-]|\\d+[.])[ \\t]+([^\\r]+?(\\n{1,2}))(?=\\n*(\\z|\\2([*+-]|\\d+[.])[ \\t]+))";
    NSRange range = NSMakeRange(0, [text length]);
    while (range.location < [text length])
    {
        NSRange r = [text rangeOfRegex: regex
                               options: RKLMultiline
                               inRange: range
                               capture: 0
                                 error: NULL];
        if (r.location == NSNotFound)
            break;
        
        NSArray *a = [text arrayOfCaptureComponentsMatchedByRegex: regex
                                                          options: RKLMultiline
                                                            range: range
                                                            error: NULL];
        a = [a objectAtIndex: 0];
        
        NSString *item = [a objectAtIndex: 4];
        NSString *leadingLine = [a objectAtIndex: 1];
        NSString *leadingSpace = [a objectAtIndex: 2];
        
        if ([leadingLine length] > 0 || [item rangeOfRegex: @"\\n{2,}"].location != NSNotFound)
        {
            item = [self runBlockGamut: [self outdent: item]];
        }
        else
        {
            item = [self doLists: [self outdent: item]];
            item = [item stringByReplacingOccurrencesOfRegex: @"\\n$"
                                                  withString: @""];
            item = [self runSpanGamut: item];
        }
        
        NSString *repl = [NSString stringWithFormat: @"<li>%@</li>\n",
                          item];
        text = [text stringByReplacingCharactersInRange: r
                                             withString: repl];
        range.location = r.location + [repl length];
        range.length = [text length] - range.location;
    }
    listLevel--;
    return text;
}

- (NSString *) doLists: (NSString *) text
{
    menter(@"doLists", @"%@", text);
    if (listLevel > 0)
    {
        // note: multiline
        NSString *wholeList = @"^(([ ]{0,3}([*+-]|\\d+[.])[ \\t]+)[^\\r]+?(\\z|\\n{2,}(?=\\S)(?![ \\t]*(?:[*+-]|\\d+[.])[ \\t]+)))";
        NSRange range = NSMakeRange(0, [text length]);
        while (range.location < [text length])
        {
            NSRange r = [text rangeOfRegex: wholeList
                                   options: RKLMultiline
                                   inRange: range
                                   capture: 0
                                     error: NULL];
            if (r.location == NSNotFound)
                break;
            
            NSArray *a = [text arrayOfCaptureComponentsMatchedByRegex: wholeList
                                                              options: RKLMultiline
                                                                range: range
                                                                error: NULL];
            a = [a objectAtIndex: 0];
            NSString *list = [[a objectAtIndex: 1] stringByReplacingOccurrencesOfRegex: @"\\n{2,}"
                                                                            withString: @"\n\n\n"];
            NSString *listType = ([[a objectAtIndex: 3] rangeOfRegex: @"[*+-]"].location != NSNotFound) ?
            @"ul" : @"ol";
            
            NSString *result = [self processListItems: list];
            result = [result stringByReplacingOccurrencesOfRegex: @"\\s+$"
                                                      withString: @""];
            result = [NSString stringWithFormat: @"<%@>%@</%@>\n", listType, result, listType];
            
            text = [text stringByReplacingCharactersInRange: r
                                                 withString: result];
            range.location = r.location + [result length];
            range.length = [text length] - range.location;
        }
    }
    else
    {
        NSString *wholeList = @"(\\n\\n|^\\n?)(([ ]{0,3}([*+-]|\\d+[.])[ \\t]+)[^\\r]+?(\\z|\\n{2,}(?=\\S)(?![ \\t]*(?:[*+-]|\\d+[.])[ \\t]+)))";
        NSRange range = NSMakeRange(0, [text length]);
        while (range.location < [text length])
        {
            NSRange r = [text rangeOfRegex: wholeList
                                   inRange: range];
            if (r.location == NSNotFound)
                break;
            
            NSArray *a = [text arrayOfCaptureComponentsMatchedByRegex: wholeList
                                                                range: range];
            a = [a objectAtIndex: 0];
            NSString *runup = [a objectAtIndex: 1];
            NSString *list = [[a objectAtIndex: 2] stringByReplacingOccurrencesOfRegex: @"\\n{2,}"
                                                                            withString: @"\n\n\n"];
            NSString *listType = ([[a objectAtIndex: 3] rangeOfRegex: @"[*+-]"].location != NSNotFound) ?
            @"ul" : @"ol";

            NSString *result = [self processListItems: list];
            result = [NSString stringWithFormat: @"%@<%@>%@</%@>\n", runup,
                      listType, result, listType];
            
            text = [text stringByReplacingCharactersInRange: r
                                                 withString: result];
            range.location = r.location + [result length];
            range.length = [text length] - range.location;
        }
    }

    mexit(@"doLists", @"%@", text);
    return text;
}

- (NSString *) doCodeBlocks: (NSString *) text
{
    menter(@"doCodeBlocks", @"%@", text);
    NSString *regex = [NSString stringWithFormat: @"(?:\\n\\n|\\A)((?:(?:[ ]{%d} | \\t).*\\n+)+)((?=^[ ]{0,%d}\\S)|\\Z)",
                       self.tabWidth, self.tabWidth];
    NSRange range = NSMakeRange(0, [text length]);
    
    while (range.location < [text length])
    {
        NSRange r = [text rangeOfRegex: regex
                               options: RKLMultiline
                               inRange: range
                               capture: 0
                                 error: NULL];
        if (r.location == NSNotFound)
            break;
        
        NSArray *a = [text arrayOfCaptureComponentsMatchedByRegex: regex
                                                          options: RKLMultiline
                                                            range: range
                                                            error: NULL];
        a = [a objectAtIndex: 0];
        
        NSString *codeblock = [a objectAtIndex: 1];
        codeblock = [self encodeCode: codeblock];
        codeblock = [self detabify: codeblock];
        codeblock = [codeblock stringByReplacingOccurrencesOfRegex: @"\\A\\n+"
                                                        withString: @""];
        codeblock = [codeblock stringByReplacingOccurrencesOfRegex: @"\\n+\\Z"
                                                        withString: @""];
        
        codeblock = [NSString stringWithFormat: @"<pre><code>%@</code></pre>",
                     codeblock];
        text = [text stringByReplacingCharactersInRange: r
                                             withString: codeblock];
    }
    mexit(@"doCodeBlocks", @"%@", text);
    return text;
}

- (NSString *) encodeCode: (NSString *) text
{
    text = [text stringByReplacingOccurrencesOfString: @"&"
                                           withString: @"&amp;"];
    text = [text stringByReplacingOccurrencesOfString: @"<"
                                           withString: @"&lt;"];
    text = [text stringByReplacingOccurrencesOfString: @">"
                                           withString: @"&gt;"];
    return escapeCharacters(text, @"\\*_{}[]\\", NO);
}

- (NSString *) doBlockQuotes: (NSString *) text
{
    NSString *regex = @"((^[ \\t]*>[ \\t]?.+\\n(.+\\n)*\\n*)+)";
    NSRange range = NSMakeRange(0, [text length]);
    while (range.location < [text length])
    {
        NSRange r = [text rangeOfRegex: regex
                               options: RKLMultiline
                               inRange: range
                               capture: 0
                                 error: NULL];
        if (r.location == NSNotFound)
            break;
        
        NSString *bq = [text substringWithRange: r];
        bq = [bq stringByReplacingOccurrencesOfRegex: @"^[ \\t]*>[ \\t]?"
                                          withString: @""
                                             options: RKLMultiline
                                               range: NSMakeRange(0, [bq length])
                                               error: NULL];
        bq = [bq stringByReplacingOccurrencesOfRegex: @"^[ \\t]+$"
                                          withString: @""
                                             options: RKLMultiline
                                               range: NSMakeRange(0, [bq length])
                                               error: NULL];
        bq = [self runBlockGamut: bq];
        bq = [bq stringByReplacingOccurrencesOfRegex: @"^"
                                          withString: @"  "];
        // TODO
        
        bq = [NSString stringWithFormat: @"<blockquote>\n%@\n</blockquote>\n\n", bq];
        text = [text stringByReplacingCharactersInRange: r
                                             withString: bq];
        range.location = r.location + [bq length];
        range.length = [text length] - range.location;
    }

    return text;
}

- (NSString *) formParagraphs: (NSString *) text
{
    menter(@"formParagraphs", @"%@", text);
    text = [text stringByReplacingOccurrencesOfRegex: @"\\A\\n+"
                                          withString: @""];
    text = [text stringByReplacingOccurrencesOfRegex: @"\\n+\\z"
                                          withString: @""];
    
    NSArray *grafs = [text componentsSeparatedByRegex: @"\\n{2,}"];
    NSLog(@"grafs: %@", grafs);
    NSMutableArray *grafsOut = [NSMutableArray arrayWithCapacity: [grafs count]];
    
    for (NSString *s in grafs)
    {
        // FIXME -- the paragraph breaking is giving me two hashes separated
        // by a newline. Did I mess something up, when hashing HTML?
        // IF I did mess this up, the while loop is wrong -- it should do that
        // once...
        NSRange r = [s rangeOfRegex: @"[A-Fa-f0-9]{32}"];
        BOOL didReplace = NO;
        while (r.location != NSNotFound)
        {
            NSString *maybeHash = [s substringWithRange: r];
            NSLog(@"maybe hash: %@", maybeHash);
            NSString *value = [blockHash objectForKey: maybeHash];
            if (value != nil)
            {
                s = [s stringByReplacingCharactersInRange: r
                                               withString: value];
                didReplace = YES;
            }
            
            r = [s rangeOfRegex: @"[A-Fa-f0-9]{32}"];
        }
        if (didReplace) // just did a hashed block.
        {
            [grafsOut addObject: s];
            continue;
        }
        if ([s isMatchedByRegex: @"\\S"])
        {
            s = [self runSpanGamut: s];
            s = [s stringByReplacingOccurrencesOfRegex: @"^([ \\t]*)"
                                            withString: @"<p>"];
            s = [s stringByAppendingString: @"</p>"];
            [grafsOut addObject: s];
        }
    }
    
    int len = [grafsOut count];
    for (int i = 0; i < len; i++)
    {
        NSString *str = [grafsOut objectAtIndex: i];
        NSRange r = [str rangeOfRegex: @"\\d|[A-Fa-f]{16}"];
        if (r.location != NSNotFound)
        {
            NSString *hash = [str substringWithRange: r];
            NSString *block = [blockHash objectForKey: hash];
            if (block != nil)
            {
                str = [str stringByReplacingCharactersInRange: r
                                                   withString: block];
                [grafsOut replaceObjectAtIndex: i
                                    withObject: str];
            }
        }
    }
    
    text = [@"\n\n" join: grafsOut];
    mexit(@"formParagraphs", @"%@", text);
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

static NSString *
escapeCharacters(NSString *text, NSString *charsToEscape, BOOL afterBackslash)
{
    NSString *regexString = [NSString stringWithFormat: @"([%@])",
                             [charsToEscape stringByReplacingOccurrencesOfRegex: @"([\\[\\]\\\\])"
                                                                     withString: @"\\$1"]];
    if (afterBackslash)
        regexString = [@"\\\\" stringByAppendingString: regexString];
    
    while (YES)
    {
        NSRange r = [text rangeOfRegex: regexString];
        
        if (r.location == NSNotFound)
            break;
        
        unichar ch = [text characterAtIndex: r.location + r.length - 2];
        text = [text stringByReplacingCharactersInRange: r
                                             withString: [NSString stringWithFormat: @"~E%dE", (int) ch]];
    }
    
    return text;
}

- (NSString *) encodeBackslashEscapes: (NSString *) text
{
    text = escapeCharacters(text, @"\\", YES);
    text = escapeCharacters(text, @"`*_{}[]()>#+-.!", YES);
    return text; // TODO
}

- (NSString *) writeImageTag: (NSArray *) matches
{
    NSString *wholeMatch = [matches objectAtIndex: 1];
    NSString *altText = [matches objectAtIndex: 2];
    NSString *linkId = [[matches objectAtIndex: 3] lowercaseString];
    NSString *url = [matches objectAtIndex: 4];
    NSString *title = [matches objectAtIndex: 7];
    
    if ([url length] == 0)
    {
        if ([linkId length] == 0)
        {
            linkId = [[altText lowercaseString] stringByReplacingOccurrencesOfRegex: @" ?\\n"
                                                                         withString: @" "];
        }
        url = [@"#" stringByAppendingString: linkId];
        
        NSString *s = [urlHash objectForKey: linkId];
        if (s != nil)
        {
            url = s;
            NSString *ss = [titlesHash objectForKey: linkId];
            if (ss != nil)
                title = ss;
        }
        else
        {
            return wholeMatch;
        }
    }
    
    altText = [altText stringByReplacingOccurrencesOfString: @"\""
                                                 withString: @"&quot;"];
    url = escapeCharacters(url, @"*_", NO);
    NSMutableString *result = [NSMutableString stringWithString: @"<img src=\""];
    [result appendString: url];
    [result appendString: @"\" alt=\""];
    [result appendString: altText];
    [result appendString: @"\""];
    
    title = [title stringByReplacingOccurrencesOfString: @"\""
                                             withString: @"&quot;"];
    title = escapeCharacters(title, @"*_", NO);
    [result appendString: @" title=\""];
    [result appendString: title];
    [result appendString: @"\""];
    [result appendString: self.emptyElementSuffix];
    return result;
}

- (NSString *) doImages: (NSString *) text
{
    NSRange range = NSMakeRange(0, [text length]);
    while (range.location < [text length])
    {
        NSRange r = [text rangeOfRegex: @"(!\\[(.*?)\\][ ]?(?:\\n[ ]*)?\\[(.*?)\\])()()()()"
                               options: RKLNoOptions
                               inRange: range
                               capture: 0
                                 error: NULL];
        if (r.location == NSNotFound)
            break;

        NSArray *a = [text arrayOfCaptureComponentsMatchedByRegex: @"(!\\[(.*?)\\][ ]?(?:\\n[ ]*)?\\[(.*?)\\])()()()()"
                                                            range: range];

        NSString *tag = [self writeImageTag: [a objectAtIndex: 0]];
        text = [text stringByReplacingCharactersInRange: r
                                             withString: tag];
        
        range.location = r.location + [tag length];
        range.length = [text length] - range.location;
    }

    // text = text.replace(/(!\[(.*?)\]\s?\([ \t]*()<?(\S+?)>?[ \t]*((['"])(.*?)\6[ \t]*)?\))/g,writeImageTag);
    range = NSMakeRange(0, [text length]);
    while (YES)
    {
        NSRange r = [text rangeOfRegex: @"(!\\[(.*?)\\]\\s?\\([ \\t]*()<?(\\S+?)>?[ \\t]*((['\"])(.*?)\6[ \\t]*)?\\))"
                               options: RKLNoOptions
                               inRange: range
                               capture: 0
                                 error: NULL];
        if (r.location == NSNotFound)
            break;

        NSArray *a = [text arrayOfCaptureComponentsMatchedByRegex: @"(!\\[(.*?)\\]\\s?\\([ \\t]*()<?(\\S+?)>?[ \\t]*((['\"])(.*?)\6[ \\t]*)?\\))"
                                                            range: range];        
        a = [a objectAtIndex: 0];
        
        NSString *tag = [self writeImageTag: a];
        text = [text stringByReplacingCharactersInRange: r
                                             withString: tag];
        
        range.location = r.location + [tag length];
        range.length = [text length] - range.location;
    }
    
    return text;
}

- (NSString *) writeAnchorTag: (NSArray *) groups
{
    NSString *wholeMatch = [groups objectAtIndex: 1];
    NSString *linkText = [groups objectAtIndex: 2];
    NSString *linkId = [[groups objectAtIndex: 3] lowercaseString];
    NSString *url = [groups objectAtIndex: 4];
    NSString *title = [groups objectAtIndex: 7];
    
    if (url == nil || [url length] == 0)
    {
        if (linkId == nil || [linkId length] == 0)
        {
            linkId = [[linkText lowercaseString] stringByReplacingOccurrencesOfRegex: @" +\\n"
                                                                          withString: @" "];
        }
        url = [@"#" stringByAppendingString: linkId];
    
        NSString *linkValue = [urlHash objectForKey: linkId];
        if (linkValue != nil)
        {
            url = linkValue;
            NSString *s = [titlesHash objectForKey: linkId];
            if (s != nil)
                title = s;
        }
        else
        {
            if ([wholeMatch isMatchedByRegex: @"\\(\\s*\\)$"
                                     options: RKLMultiline
                                     inRange: NSMakeRange(0, [wholeMatch length])
                                       error: NULL])
            {
                url = @"";
            }
            else
            {
                return wholeMatch;
            }
        }
    }
    
    url = escapeCharacters(url, @"*_", NO);
    NSMutableString *result = [NSMutableString stringWithString: @"<a href=\""];
    [result appendString: url];
    [result appendString: @"\""];
    
    if (title != nil && [title length] > 0)
    {
        title = [title stringByReplacingOccurrencesOfString: @"\"" withString: @"&quot;"];
        title = escapeCharacters(title, @"*_", NO);
        [result appendString: @" title=\""];
        [result appendString: title];
        [result appendString: @"\""];
    }
    
    [result appendString: @">"];
    [result appendString: linkText];
    [result appendString: @"</a>"];
    return result;
}

- (NSString *) doAnchors: (NSString *) text
{
    NSRange range = NSMakeRange(0, [text length]);
    while (range.location < [text length])
    {
        NSRange r = [text rangeOfRegex: @"(\\[((?:\\[[^\\]]*\\]|[^\\[\\]])*)\\][ ]?(?:\\n[ ]*)?\\[(.*?)\\])()()()()"
                               options: RKLNoOptions
                               inRange: range
                               capture: 0
                                 error: NULL];
        if (r.location == NSNotFound)
            break;
        
        NSArray *a = [text arrayOfCaptureComponentsMatchedByRegex: @"(\\[((?:\\[[^\\]]*\\]|[^\\[\\]])*)\\][ ]?(?:\\n[ ]*)?\\[(.*?)\\])()()()()"
                                                          options: RKLNoOptions
                                                            range: r
                                                            error: NULL];
        a = [a objectAtIndex: 0];
        
        NSString *repl = [self writeAnchorTag: a];
        text = [text stringByReplacingCharactersInRange: r
                                             withString: repl];
        range.location = r.location + [repl length];
        range.length = [text length] - range.location;
    }
    
    range = NSMakeRange(0, [text length]);
    while (range.location < [text length])
    {
        NSRange r = [text rangeOfRegex: @"(\\[((?:\\[[^\\]]*\\]|[^\\[\\]])*)\\]\\([ \\t]*()<?(.*?)>?[ \\t]*((['\"])(.*?)\\6[ \\t]*)?\\))"
                               options: RKLNoOptions
                               inRange: range
                               capture: 0
                                 error: NULL];
        
        if (r.location == NSNotFound)
            break;
        
        NSArray *a = [text arrayOfCaptureComponentsMatchedByRegex: @"(\\[((?:\\[[^\\]]*\\]|[^\\[\\]])*)\\]\\([ \\t]*()<?(.*?)>?[ \\t]*((['\"])(.*?)\\6[ \\t]*)?\\))"
                                                          options: RKLNoOptions
                                                            range: r
                                                            error: NULL];
        a = [a objectAtIndex: 0];
        NSString *repl = [self writeAnchorTag: a];
        text = [text stringByReplacingCharactersInRange: r
                                             withString: repl];
        range.location = r.location + [repl length];
        range.length = [text length] - range.location;
    }
    
    range = NSMakeRange(0, [text length]);
    while (range.location < [text length])
    {
        NSRange r = [text rangeOfRegex: @"(\\[([^\\[\\]]+)\\])()()()()()"
                               options: RKLNoOptions
                               inRange: range
                               capture: 0
                                 error: NULL];
        if (r.location == NSNotFound)
            break;
        
        NSArray *a = [text arrayOfCaptureComponentsMatchedByRegex: @"(\\[([^\\[\\]]+)\\])()()()()()"
                                                          options: RKLNoOptions
                                                            range: r
                                                            error: NULL];
        a = [a objectAtIndex: 0];
        NSString *repl = [self writeAnchorTag: a];
        text = [text stringByReplacingCharactersInRange: r
                                             withString: repl];
        range.location = r.location + [repl length];
        range.length = [text length] - range.location;        
    }
    
    mexit(@"doAnchors", @"%@", text);
    return text;
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
        
        if (self.encodeEmailAddresses)
        {
            srandom(time(NULL));
            
            NSMutableString *encmailto = [NSMutableString stringWithCapacity: 10];
            NSMutableString *encaddr = [NSMutableString stringWithCapacity: [addr length]];
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
        else
        {
            text = [text stringByReplacingCharactersInRange: r
                                                 withString: [NSString stringWithFormat: @"<a href=\"mailto:%@\">%@</a>",
                                                              addr, addr]];
        }

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
    return text;
}

@end


@implementation MDKStringConverter

@synthesize encodeEmailAddresses;
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
        self.encodeEmailAddresses = YES;
        
        blockHash = [[NSMutableDictionary alloc] init];
        urlHash = [[NSMutableDictionary alloc] init];
        titlesHash = [[NSMutableDictionary alloc] init];
    }
    return self;
}

- (void) dealloc
{
    [blockHash release];
    [urlHash release];
    [titlesHash release];
    [super dealloc];
}

- (NSString *) convertMarkdownStringToHTML:(NSString *)markdown
{
    menter(@"convertMarkdownStringToHTML", @"%@", markdown);
    [blockHash removeAllObjects];
    [urlHash removeAllObjects];
    [titlesHash removeAllObjects];
    listLevel = 0;

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
    text = [text stringByAppendingString: @"\n"];
    
    NSLog(@"urlHash: %@", urlHash);
    NSLog(@"titlesHash: %@", titlesHash);
    NSLog(@"blockHash: %@", blockHash);
    
    mexit(@"convertMarkdownStringToHTML", @"%@", text);
    return text;
}

@end
