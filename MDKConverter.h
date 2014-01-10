//
//  MDKConverter.h
//  MarkdownKit
//
//  Created by Casey Marshall on 1/9/14.
//
//

#import <Foundation/Foundation.h>
#import "MDKDocument.h"

@interface MDKConverter : NSObject
{
    MDKDocument *doc;
}

- (id) initWithDocument: (MDKDocument *) _doc;

- (BOOL) writeCSSToFileHandle: (NSFileHandle *) fh;
- (BOOL) writeTOCToFileHandle: (NSFileHandle *) fh;
- (BOOL) writeHTMLToFileHandle: (NSFileHandle *) fh;

- (NSString *) htmlString;

@end
