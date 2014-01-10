//
//  MDKMarkdown.m
//  MarkdownKit
//
//  Created by Casey Marshall on 1/9/14.
//
//

#import "MDKMarkdown.h"
#import "MDKConverter.h"

@implementation MDKMarkdown

+ (NSString *) htmlStringForMarkdownString: (NSString *) str
                                     flags: (MDKFlags) flags
{
    NSString *ret = nil;
    MDKDocument *doc = [[MDKDocument alloc] initWithString: str
                                                     flags: flags];
    if (doc != nil)
    {
        MDKConverter *conv = [[MDKConverter alloc] initWithDocument: doc];
        if (conv != nil)
        {
            ret = [conv htmlString];
#if ! __has_feature(objc_arc)
            [conv release];
#endif
        }
        
#if ! __has_feature(objc_arc)
        [doc release];
#endif
    }
    return ret;
}

@end
