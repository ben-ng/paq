//
//  JSContextExtensions.cpp
//  paq
//
//  Created by Ben on 3/28/15.
//  Copyright (c) 2015 Ben Ng. All rights reserved.
//

#import <iostream>
#import "JSContextExtensions.h"

JSContext* JSContextExtensions::create()
{
    JSContext* ctx = [[JSContext alloc] init];

    NSArray* logFunctions = @[ @"log", @"info", @"warn", @"debug", @"error" ];

    ctx[@"setTimeout"] = ^(JSValue* function, JSValue* timeout) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)([timeout toInt32] * NSEC_PER_MSEC)), dispatch_get_main_queue(), ^{
            [function callWithArguments:@[]];
        });
    };

    ctx[@"setImmediate"] = ^(JSValue* function, JSValue* timeout) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)([timeout toInt32] * NSEC_PER_MSEC)), dispatch_get_main_queue(), ^{
            [function callWithArguments:@[]];
        });
    };

    [ctx evaluateScript:@"console = {}"];

    for (NSUInteger i = 0, ii = logFunctions.count; i < ii; ++i) {
        [ctx evaluateScript:[NSString stringWithFormat:@"console.%@ = function noop(){}", logFunctions]];
    }

    return ctx;
}

void JSContextExtensions::destroy(JSContext* ctx)
{
    ctx[@"setTimeout"] = nil;
    ctx[@"setImmediate"] = nil;
}
