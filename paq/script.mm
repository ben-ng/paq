//
//  script.mm
//  paq
//
//  Created by Ben on 3/25/15.
//  Copyright (c) 2015 Ben Ng. All rights reserved.
//

#include "script.h"

JSContext* Script::loadEmbeddedBundle(std::string sectionName, NSString* afterLoad)
{

    JSContext* ctx = JSContextExtensions::create();

    ctx.exceptionHandler = ^(JSContext* context, JSValue* exception) {
        NSLog(@"JS Error: %@", [exception toString]);
    };

    unsigned long size;
    void* JS_SOURCE = getsectiondata(&_mh_execute_header, "__TEXT", sectionName.c_str(), &size);

    if (size == 0) {
        NSLog(@"The section \"%s\"  is missing from the __TEXT segment", sectionName.c_str());
    }
    else {
        NSString* src = [[NSString alloc] initWithBytesNoCopy:JS_SOURCE length:size encoding:NSUTF8StringEncoding freeWhenDone:NO];

        [ctx evaluateScript:src];

        if (afterLoad) {
            [ctx evaluateScript:afterLoad];
        }
    }

    ctx.exceptionHandler = nil;

    return ctx;
};
