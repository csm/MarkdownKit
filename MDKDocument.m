//
//  MDKTextInput.m
//  MarkdownKit
//
//  Created by Casey Marshall on 1/9/14.
//
//

#import "MDKDocument.h"
#import "_MDKDocumentContext.h"
#import "markdown.h"

static unsigned int _convert_flags(MDKFlags flags)
{
    unsigned int _flags = 0;
    if ((flags & kMDKFlagAutoLink) != 0) _flags |= MKD_AUTOLINK;
    if ((flags & kMDKFlagCDATA) != 0) _flags |= MKD_CDATA;
    if ((flags & kMDKFlagCompat1) != 0) _flags |= MKD_1_COMPAT;
    if ((flags & kMDKFlagExtraFootnote) != 0) _flags |= MKD_EXTRA_FOOTNOTE;
    if ((flags & kMDKFlagNoAlphaList) != 0) _flags |= MKD_NOALPHALIST;
    if ((flags & kMDKFlagNoDIVQuote) != 0) _flags |= MKD_NODIVQUOTE;
    if ((flags & kMDKFlagNoDList) != 0) _flags |= MKD_NODLIST;
    if ((flags & kMDKFlagNoExt) != 0) _flags |= MKD_NO_EXT;
    if ((flags & kMDKFlagNoHeader) != 0) _flags |= MKD_NOHEADER;
    if ((flags & kMDKFlagNoHTML) != 0) _flags |= MKD_NOHTML;
    if ((flags & kMDKFlagNoImage) != 0) _flags |= MKD_NOIMAGE;
    if ((flags & kMDKFlagNoLinks) != 0) _flags |= MKD_NOLINKS;
    if ((flags & kMDKFlagNoPants) != 0) _flags |= MKD_NOPANTS;
    if ((flags & kMDKFlagNoRelaxed) != 0) _flags |= MKD_NORELAXED;
    if ((flags & kMDKFlagNoStrikethrough) != 0) _flags |= MKD_NOSTRIKETHROUGH;
    if ((flags & kMDKFlagNoSuperscript) != 0) _flags |= MKD_NOSUPERSCRIPT;
    if ((flags & kMDKFlagNoTables) != 0) _flags |= MKD_NOTABLES;
    if ((flags & kMDKFlagSafeLink) != 0) _flags |= MKD_SAFELINK;
    if ((flags & kMDKFlagStrict) != 0) _flags |= MKD_STRICT;
    if ((flags & kMDKFlagTabStop) != 0) _flags |= MKD_TABSTOP;
    if ((flags & kMDKFlagTagText) != 0) _flags |= MKD_TAGTEXT;
    if ((flags & kMDKFlagTOC) != 0) _flags |= MKD_TOC;
    return _flags;
}

@implementation MDKDocument

- (id) initWithContentsOfFile: (NSString *) filePath
                        flags: (MDKFlags) flags
{
    if (self = [super init])
    {
        FILE *f = fopen([filePath UTF8String], "r");
        if (f == NULL)
            return nil;
        unsigned int _flags = _convert_flags(flags);
        if ((flags & kMDKFlagGithubFlavored) == 0)
            _context = [[_MDKDocumentContext alloc] initWithDocument: mkd_in(f, _flags)];
        else
            _context = [[_MDKDocumentContext alloc] initWithDocument: gfm_in(f, _flags)];
        mkd_compile(_context.context, _flags);
    }
    return self;
}

- (id) initWithString:(NSString *)contents flags:(MDKFlags)flags
{
    if (self = [super init])
    {
        const char *utf8 = [contents UTF8String];
        unsigned int _flags = _convert_flags(flags);
        if ((flags & kMDKFlagGithubFlavored) == 0)
            _context = [[_MDKDocumentContext alloc] initWithDocument: mkd_string(utf8, (int) strlen(utf8), _flags)];
        else
            _context = [[_MDKDocumentContext alloc] initWithDocument: gfm_string(utf8, (int) strlen(utf8), _flags)];
        mkd_compile(_context.context, _flags);
    }
    return self;
}

@end
