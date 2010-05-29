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
}

@property (nonatomic, assign) NSUInteger tabWidth;

- (NSString *) convertMarkdownStringToHTML: (NSString *) markdown;

@end
