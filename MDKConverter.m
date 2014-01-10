//
//  MDKConverter.m
//  MarkdownKit
//
//  Created by Casey Marshall on 1/9/14.
//
//

#import "MDKConverter.h"
#import "MDKDocument+privateMethods.h"
#import "markdown.h"

// discount is a weirdly written library...
int mkd_generatetoc(Document *, FILE *);

@implementation MDKConverter

- (id) initWithDocument:(MDKDocument *)_doc
{
    if (self = [super init])
    {
        doc = _doc;
#if ! __has_feature(objc_arc)
        [doc retain];
#endif
    }
    return self;
}

- (NSString *) htmlString
{
    char *result = NULL;
    mkd_document([doc context].context, &result);
    if (result == NULL)
        return nil;
    return [NSString stringWithUTF8String: result];
}

- (BOOL) writeHTMLToFileHandle:(NSFileHandle *) fh
{
    FILE *f = fdopen([fh fileDescriptor], "w");
    if (f == NULL)
        return NO;
    mkd_generatehtml([doc context].context, f);
    return YES;
}

- (BOOL) writeCSSToFileHandle:(NSFileHandle *)fh
{
    FILE *f = fdopen([fh fileDescriptor], "w");
    if (f == NULL)
        return NO;
    mkd_generatecss([doc context].context, f);
    return YES;
}

- (BOOL) writeTOCToFileHandle:(NSFileHandle *)fh
{
    FILE *f = fdopen([fh fileDescriptor], "w");
    if (f == NULL)
        return NO;
    mkd_generatetoc([doc context].context, f);
    return YES;
}

@end
