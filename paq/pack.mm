//
//  pack.mm
//  paq
//
//  Created by Ben on 3/26/15.
//  Copyright (c) 2015 Ben Ng. All rights reserved.
//

#import "pack.h"

NSString* JSONString(NSString* astring)
{
    NSMutableString* s = [NSMutableString stringWithString:astring];
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
    return [NSString stringWithString:s];
}

void Pack::pack(NSArray* entry, NSDictionary* deps, NSDictionary* options,
    void (^callback)(NSError* error, NSString* bundle))
{
    NSString* prelude;
    unsigned long size;
    void* JS_SOURCE = getsectiondata(&_mh_execute_header, "__TEXT", "__prelude_src", &size);

    if (size == 0) {
        NSLog(@"The section \"%s\"  is missing from the __TEXT segment",
            "__prelude_src");
    }
    else {
        prelude = [[NSString alloc] initWithBytesNoCopy:JS_SOURCE
                                                 length:size
                                               encoding:NSUTF8StringEncoding
                                           freeWhenDone:NO];
    }

    NSMutableString* output = [[NSMutableString alloc] initWithString:prelude];

    [output appendString:@"({\n"];

    __block unsigned long counter = 0;
    long depscount = [deps count];

    NSMutableArray* entryFiles =
        [[NSMutableArray alloc] initWithCapacity:[entry count]];

    [deps enumerateKeysAndObjectsUsingBlock:^(NSString* key, NSDictionary* obj,
                                                BOOL* stop) {
    counter++;

    [output appendFormat:@"\"%@\"", JSONString(key)];
    [output appendString:@": [function (require, module, exports) {\n"];
    [output appendString:obj[@"source"]];
    [output appendString:@"\n}, "];

    NSError *error;
    NSData *serialized = [NSJSONSerialization dataWithJSONObject:obj[@"deps"]
                                                         options:0
                                                           error:&error];

    if (error) {
     return callback([NSError errorWithDomain:@"com.benng.paq" code:6 userInfo:@{NSLocalizedDescriptionKey: @"The dependency object could not be serialized"}], nil);
    }

    [output appendString:[[NSString alloc] initWithData:serialized
                                               encoding:NSUTF8StringEncoding]];
    [output appendString:@"]"];

    if (counter < depscount) {
      [output appendString:@",\n"];
    }

    if ([obj[@"entry"] boolValue]) {
      [entryFiles addObject:key];
    }
    }];

    [output appendString:@"},{},"];

    NSError* error;
    NSData* serialized = [NSJSONSerialization dataWithJSONObject:entryFiles
                                                         options:0
                                                           error:&error];

    if (error) {
        return callback([NSError errorWithDomain:@"com.benng.paq" code:6 userInfo:@{ NSLocalizedDescriptionKey : @"The entry array could not be serialized" }], nil);
    }

    [output appendString:[[NSString alloc] initWithData:serialized
                                               encoding:NSUTF8StringEncoding]];
    [output appendString:@")"];

    if (options != nil && [options[@"eval"] boolValue]) {
        if ([entry count] != 1) {
            return callback([NSError errorWithDomain:@"com.benng.paq"
                                                code:1
                                            userInfo:@{
                                                NSLocalizedDescriptionKey :
                                                    @"The eval option can only be used "
                                                @"when there is one entry script"
                                            }],
                nil);
        }

        [output appendFormat:@"(\"%@\")", JSONString(entry[0])];
    }

    // Close with a string
    [output appendString:@"\n"];

    callback(nil, output);
}