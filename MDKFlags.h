//
//  MDKFlags.h
//  MarkdownKit
//
//  Created by Casey Marshall on 1/9/14.
//
//

#import <Foundation/Foundation.h>

#pragma mark - Constants

typedef NSUInteger MDKFlags;

#define kMDKFlagNoLinks (1<<0)  /**< Don’t do link processing, block `<a>` tags */
#define kMDKFlagNoImage (1<<1)  /**< Don’t do image processing, block `<img>` */
#define kMDKFlagNoPants (1<<2)  /**< Don’t run `smartypants()` */
#define kMDKFlagNoHTML (1<<3)   /**< Don’t allow raw html through **AT ALL** */
#define kMDKFlagStrict (1<<4)   /**< Disable `SUPERSCRIPT`, `RELAXED_EMPHASIS` */
#define kMDKFlagTagText (1<<5)  /**< Process text inside an html tag; no `<em>`, no `<bold>`, no html or `[]` expansion */
#define kMDKFlagNoExt (1<<6)        /**< Don’t allow pseudo-protocols */
#define kMDKFlagCDATA (1<<7)        /**< Generate code for xml `![CDATA[...]]` */
#define kMDKFlagNoSuperscript (1<<8)/**< No `A^B` */
#define kMDKFlagNoRelaxed (1<<9)    /**< Emphasis happens _everywhere_ */
#define kMDKFlagNoTables (1<<10)    /**< Don’t process [PHP Markdown Extra](http://michelf.com/projects/php-markdown/extra/) tables. */
#define kMDKFlagNoStrikethrough (1<<11) /**< Forbid `~~strikethrough~~` */
#define kMDKFlagTOC (1<<12)         /**< Do table-of-contents processing */
#define kMDKFlagCompat1 (1<<13)     /**< Compatability with MarkdownTest_1.0 */
#define kMDKFlagAutoLink (1<<14)    /**< Make `http://foo.com` a link even without <>s */
#define kMDKFlagSafeLink (1<<15)    /**< Paranoid check for link protocol */
#define kMDKFlagNoHeader (1<<16)    /**< Don’t process document headers */
#define kMDKFlagTabStop (1<<17)     /**< Expand tabs to 4 spaces */
#define kMDKFlagNoDIVQuote (1<<18)  /**< Forbid >%class% blocks */
#define kMDKFlagNoAlphaList (1<<19) /**< Forbid alphabetic lists */
#define kMDKFlagNoDList (1<<20)     /**< Forbid definition lists */
#define kMDKFlagExtraFootnote (1<<21) /**< Enable [PHP Markdown Extra](http://michelf.com/projects/php-markdown/extra/)-style [footnotes](http://michelf.com/projects/php-markdown/extra/#footnotes). */
#define kMDKFlagGithubFlavored (1<<22) /**< Generate using Github-flavored markdown */
