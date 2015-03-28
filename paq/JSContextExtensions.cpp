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

    void (^setTimeout)(JSValue*, JSValue*) = ^(JSValue* function, JSValue* timeout) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)([timeout toInt32] * NSEC_PER_MSEC)), dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [function callWithArguments:@[]];
        });
    };

    NSArray* logFunctions = @[ @"log", @"info", @"warn", @"debug", @"error" ];

    ctx[@"setTimeout"] = setTimeout;
    ctx[@"setImmediate"] = setTimeout;
    [ctx evaluateScript:@"console = {}"];

    for (NSUInteger i = 0, ii = logFunctions.count; i < ii; ++i) {
        [ctx evaluateScript:[NSString stringWithFormat:@"console.%@ = function noop(){}", logFunctions]];
    }

    return ctx;
}
