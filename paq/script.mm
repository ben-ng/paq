//
//  script.mm
//  paq
//
//  Created by Ben on 3/25/15.
//  Copyright (c) 2015 Ben Ng. All rights reserved.
//

#include "script.h"

NSDictionary* Script::getNativeBuiltins()
{
    unsigned long size;
    void* JS_SOURCE = getsectiondata(&_mh_execute_header, "__TEXT", "__builtins_src", &size);
    NSString* moduleRoot = Script::getModuleRoot();

    NSError* err = nil;
    NSDictionary* output = [NSJSONSerialization JSONObjectWithData:[NSData dataWithBytesNoCopy:JS_SOURCE length:size freeWhenDone:NO] options:0 error:&err];

    NSMutableDictionary* absoluteOutput = [[NSMutableDictionary alloc] initWithCapacity:output.count];

    [output enumerateKeysAndObjectsUsingBlock:^(NSString* builtin, NSString* relPath, BOOL* stop) {
        NSString* absPath = [[moduleRoot stringByAppendingPathComponent:relPath] stringByStandardizingPath];
        absoluteOutput[builtin] = absPath;
    }];

    return absoluteOutput;
}

NSString* Script::getModuleRoot()
{
    return [[NSProcessInfo.processInfo.arguments[0] stringByDeletingLastPathComponent] stringByDeletingLastPathComponent];
}
