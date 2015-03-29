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

    if (size == 0) {
        [NSException raise:@"Fatal Exception" format:@"The __builtins_src section is missing"];
    }

    NSError* err = nil;
    NSDictionary* output = [NSJSONSerialization JSONObjectWithData:[NSData dataWithBytesNoCopy:JS_SOURCE length:size freeWhenDone:NO] options:0 error:&err];

    if (output == nil) {
        [NSException raise:@"Fatal Exception" format:@"Could not parse the __builtins_src data as JSON"];
    }

    return output;
}
