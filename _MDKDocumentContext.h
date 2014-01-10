//
//  _MDKDocumentContext.h
//  MarkdownKit
//
//  Created by Casey Marshall on 1/9/14.
//
//

#import <Foundation/Foundation.h>

#import "markdown.h"

@interface _MDKDocumentContext : NSObject
{
    Document *iot;
}

@property (readonly) Document *context;

- (id) initWithDocument: (Document *) _iot;

@end
