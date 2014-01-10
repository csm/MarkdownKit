//
//  MDKMarkdown.h
//  MarkdownKit
//
//  Created by Casey Marshall on 1/9/14.
//
//

#import <Foundation/Foundation.h>
#import "MDKFlags.h"

@interface MDKMarkdown : NSObject

+ (NSString *) htmlStringForMarkdownString: (NSString *) str
                                     flags: (MDKFlags) flags;

@end
