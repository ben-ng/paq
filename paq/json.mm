//
//  json.mm
//  paq
//
//  Created by Ben on 3/26/15.
//  Copyright (c) 2015 Ben Ng. All rights reserved.
//

#import "json.h"

/**
 * Escapes the string for use in double quotes in js code
 */
NSString* JSONString(NSString* input)
{
    NSMutableString* s = [NSMutableString stringWithString:input];
    [s replaceOccurrencesOfString:@"\""
                        withString:@"\\\""
                           options:NSCaseInsensitiveSearch
                             range:NSMakeRange(0, [s length])];
    [s replaceOccurrencesOfString:@"/"
                        withString:@"\\/"
                           options:NSCaseInsensitiveSearch
                             range:NSMakeRange(0, [s length])];
    [s replaceOccurrencesOfString:@"\n"
                        withString:@"\\n"
                           options:NSCaseInsensitiveSearch
                             range:NSMakeRange(0, [s length])];
    [s replaceOccurrencesOfString:@"\b"
                        withString:@"\\b"
                           options:NSCaseInsensitiveSearch
                             range:NSMakeRange(0, [s length])];
    [s replaceOccurrencesOfString:@"\f"
                        withString:@"\\f"
                           options:NSCaseInsensitiveSearch
                             range:NSMakeRange(0, [s length])];
    [s replaceOccurrencesOfString:@"\r"
                        withString:@"\\r"
                           options:NSCaseInsensitiveSearch
                             range:NSMakeRange(0, [s length])];
    [s replaceOccurrencesOfString:@"\t"
                        withString:@"\\t"
                           options:NSCaseInsensitiveSearch
                             range:NSMakeRange(0, [s length])];
    return [NSString stringWithFormat:@"\"%@\"", s];
}
