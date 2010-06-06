//
//  MDKStringConverter.h
//  MarkdownKit
//
//  Created by Casey Marshall on 5/16/10.
//  Copyright 2010 Modal Domains. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "RegexKitLite.h"

@interface MDKStringConverter : NSObject
{
    NSUInteger tabWidth;
    NSString *emptyElementSuffix;
    NSMutableDictionary *blockHash;
    NSMutableDictionary *urlHash;
    NSMutableDictionary *titlesHash;
}

/**
 * The number of spaces a tab represents. The default is 4.
 */
@property (nonatomic, assign) NSUInteger tabWidth;

/**
 * The suffix to append to empty elements. By default, this is the string @">".
 * If writing XHTML, this should be @"/>".
 */
@property (nonatomic, retain) NSString *emptyElementSuffix;

- (NSString *) convertMarkdownStringToHTML: (NSString *) markdown;

@end
