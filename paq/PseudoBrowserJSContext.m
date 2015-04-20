//
//  PseudoBrowserJSContext.m
//  paq
//
//  Created by Ben on 4/19/15.
//  Copyright (c) 2015 Ben Ng. All rights reserved.
//

#import "PseudoBrowserJSContext.h"

@implementation PseudoBrowserJSContext

- (PseudoBrowserJSContext*)init
{
    self = [super init];

    if (self) {
        self.exceptionHandler = ^(JSContext* ctx, JSValue* value) {
            NSLog(@"PBSJC Exception: %@", [value toString]);
        };

        NSArray* logFunctions = @[ @"log", @"info", @"warn", @"debug", @"error" ];

        self[@"_consoleObjcBridge"] = ^(JSValue* arg) {
            NSLog(@"console: %@", [arg toString]);
        };

        [self evaluateScript:@"var console = {}"];

        // Fill in the console global with the functions people expect
        for (NSUInteger i = 0, ii = logFunctions.count; i < ii; ++i) {
            [self evaluateScript:[NSString stringWithFormat:@"console.%@ = function () {\n"
                                           @"  _consoleObjcBridge(Array.prototype.slice.call(arguments).join(' '))\n"
                                           @"}\n",
                                           logFunctions[i]]];
        }

        // setTimeout is a TRICKY BEAST!
        NSString* timeoutShim = @""
            @"var __PBSJC_funcHandles = []\n"
            @"  , __PBSJC_funcHandleCount = 0\n"
            @"  , __PBSJC_drain = function __PBSJC_drain () {\n"
            @"      var extracted, i, ii, cur\n"
            @"      while (__PBSJC_funcHandles.length) {\n"
            @"        extracted = __PBSJC_funcHandles\n"
            @"        __PBSJC_funcHandles = []\n"
            @"        extracted.sort(function (a, b) {\n"
            @"          return a[1] - b[1]\n"
            @"        })\n"
            @"        for (i=0, ii=extracted.length; i<ii; ++i) {\n"
            @"          cur = extracted[i]\n"
            @"          if (cur[3] === true) {\n"
            @"            __PBSJC_funcHandles.push(cur)\n"
            @"          }\n"
            @"          cur[0]()\n"
            @"        }\n"
            @"      }\n"
            @"    }\n"
            @"  , __PBSJC_clearFunc = function __PBSJC_clearFunc (handle) {\n"
            @"      var i, ii\n"
            @"      for (i=0, ii=__PBSJC_funcHandles.length; i<ii; ++i) {\n"
            @"        if (__PBSJC_funcHandles[i][2] === handle) {\n"
            @"          __PBSJC_funcHandles.splice(i, 1)\n"
            @"          return\n"
            @"        }\n"
            @"      }\n"
            @"    }\n"
            @"  , __PBSJC_queueFunc = function __PBSJC_queueFunc (func, delay) {\n"
            @"      __PBSJC_funcHandles.push([func, delay, __PBSJC_funcHandleCount++, false])\n"
            @"    }\n"
            @"  , __PBSJC_queueIntv = function __PBSJC_queueFunc (func, delay) {\n"
            @"      __PBSJC_funcHandles.push([func, delay, __PBSJC_funcHandleCount++, true])\n"
            @"    }\n"
            @"  , setTimeout = __PBSJC_queueFunc\n"
            @"  , setImmediate = __PBSJC_queueFunc\n"
            @"  , setInterval = __PBSJC_queueIntv\n"
            @"  , clearTimeout = __PBSJC_clearFunc\n"
            @"  , clearInterval = __PBSJC_clearFunc\n"
            @"  , clearImmediate = __PBSJC_clearFunc\n";

        [self evaluateScript:timeoutShim];
    }

    return self;
}

- (void)dealloc
{
}

@end
