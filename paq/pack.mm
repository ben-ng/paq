//
//  pack.mm
//  paq
//
//  Created by Ben on 3/26/15.
//  Copyright (c) 2015 Ben Ng. All rights reserved.
//

#import "pack.h"

/**
 * Given an entry file, the dependency map, and some options,
 * returns a bundle that can be used in any javascript environment,
 * including a browser.
 */
void Pack::pack(NSArray* entry, NSDictionary* deps, NSDictionary* options,
    void (^callback)(NSError* error, NSString* bundle))
{
    unsigned long size;
    void* JS_SOURCE = getsectiondata(&_mh_execute_header, "__TEXT", "__prelude_src", &size);

    if (size == 0) {
        return callback([NSError errorWithDomain:@"com.benng.paq" code:8 userInfo:@{ NSLocalizedDescriptionKey : @"Prelude is missing from __TEXT segment" }], nil);
    }

    NSMutableString* output = [[NSMutableString alloc] initWithBytesNoCopy:JS_SOURCE length:size encoding:NSUTF8StringEncoding freeWhenDone:NO];

    [output appendString:@"({\n"];

    __block NSUInteger counter = 0;
    NSUInteger depscount = [deps count];

    NSMutableArray* entryFiles =
        [[NSMutableArray alloc] initWithCapacity:[entry count]];

    [deps enumerateKeysAndObjectsUsingBlock:^(NSString* key, NSDictionary* obj, BOOL* stop) {
        counter++;

        [output appendString:JSONString(key)];
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

        [output appendFormat:@"(%@)", JSONString(entry[0])];
    }

    if (options != nil && [options[@"standalone"] boolValue]) {
        if ([entry count] != 1) {
            return callback([NSError errorWithDomain:@"com.benng.paq"
                                                code:13
                                            userInfo:@{
                                                NSLocalizedDescriptionKey :
                                                    @"The standalone option can only be used "
                                                @"when there is one entry script"
                                            }],
                nil);
        }

        output = [NSMutableString stringWithFormat:@"module.exports=%@(%@)", output, JSONString(entry[0])];
    }

    if (options != nil && [options[@"convertBrowserifyTransform"] boolValue]) {
        if ([entry count] != 1) {
            return callback([NSError errorWithDomain:@"com.benng.paq"
                                                code:14
                                            userInfo:@{
                                                NSLocalizedDescriptionKey :
                                                    @"The convertBrowserifyTransform option can only be used "
                                                @"when there is one entry script"
                                            }],
                nil);
        }

        unsigned long size;
        void* JS_SOURCE = getsectiondata(&_mh_execute_header, "__TEXT", "__concats_src", &size);

        if (size == 0) {
            return callback([NSError errorWithDomain:@"com.benng.paq"
                                                code:15
                                            userInfo:@{
                                                NSLocalizedDescriptionKey :
                                                    @"The concat-stream source is missing"
                                            }],
                nil);
        }

        NSString* concat_src = [[NSString alloc] initWithBytesNoCopy:JS_SOURCE length:size encoding:NSUTF8StringEncoding freeWhenDone:NO];

        // Provides a global object and the concat-stream module to the wrapped transform
        // Holy shit this is terrible
        output = [NSMutableString stringWithFormat:@"\n\n"
                                  @"// Create a fake commonjs context for concat-stream\n"
                                  @"var s=module;\n"
                                  @"module={exports:global};\n"
                                  @"%@;\n"
                                  @"var _concatstream=module.exports;\n\n"
                                  @"// Restore the real commonjs context after the module has loaded\n"
                                  @"module=s;\n"
                                  @"exports=module.exports;\n\n"
                                  @"// Load up the transform function into this variable\n"
                                  @"var t = %@(%@);\n"
                                  @"module.exports=(\n\n"
                                  @"// Wrap the exported function in its own scope for safety\n"
                                  @"function scoped (global, concatstream){\n"
                                  @"  return function wrapped (file, src, cb){\n"
                                  @"    var s=t(file);\n"
                                  @"    s.pipe(concatstream(function (data){cb(null,data)}));\n"
                                  @"    s.end(src);\n"
                                  @"  };\n"
                                  @"}({}, _concatstream));\n",
                                  concat_src, output, JSONString(entry[0])];
    }

    // Close with a string
    [output appendString:@"\n"];

    callback(nil, output);
}