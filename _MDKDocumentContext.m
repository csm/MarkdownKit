//
//  _MDKDocumentContext.m
//  MarkdownKit
//
//  Created by Casey Marshall on 1/9/14.
//
//

#import "_MDKDocumentContext.h"

@implementation _MDKDocumentContext

@synthesize context = iot;

- (id) initWithDocument: (Document *) _iot
{
    if (self = [super init])
    {
        iot = _iot;
    }
    return self;
}

- (void) dealloc
{
#if ! __has_feature(objc_arc)
    [super dealloc];
#endif
    mkd_cleanup(iot);
}

@end
