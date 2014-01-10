//
//  MDKDocument+privateMethods.h
//  MarkdownKit
//
//  Created by Casey Marshall on 1/9/14.
//
//

#import <MarkdownKit/MarkdownKit.h>
#import "MDKDocument.h"
#import "_MDKDocumentContext.h"

@interface MDKDocument (privateMethods)

- (_MDKDocumentContext *) context;

@end
