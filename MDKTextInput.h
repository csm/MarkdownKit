//
//  MDKTextInput.h
//  MarkdownKit
//
//  Created by Casey Marshall on 1/9/14.
//
//

#import <Foundation/Foundation.h>
#import "MDKFlags.h"

@class _MDKTextInputContext;

@interface MDKTextInput : NSObject
{
    _MDKTextInputContext *_context;
}

- (id) initWithContentsOfFile: (NSString *) filePath
                        flags: (MDKFlags) flags;
- (id) initWithString: (NSString *) contents
                flags: (MDKFlags) flags;

@end
