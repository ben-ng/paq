//
//  parser.mm
//  paq
//
//  Created by Ben on 3/24/15.
//  Copyright (c) 2015 Ben Ng. All rights reserved.
//

#import "parser.h"

Parser::Parser(NSDictionary* options)
{
    // Parser contexts are JSContexts with acorn loaded up inside them
    _max_tasks = options != nil && options[@"maxTasks"] ? [options[@"maxTasks"] intValue] : 2;

    if (_max_tasks <= 0) {
        _max_tasks = 1;
    }

    _accessQueue = dispatch_queue_create("parser.serial", DISPATCH_QUEUE_SERIAL);
    _virtualMachines = [[NSMutableArray alloc] initWithCapacity:0];

    for (NSUInteger i = 0; i < _max_tasks; ++i) {
        [_virtualMachines addObject:[[JSVirtualMachine alloc] init]];
    }
}

NSDictionary* Parser::parse(NSString* code, NSError** error)
{
    __block NSError* err = nil;
    __block NSUInteger selectedVirtualMachine = 0;

    dispatch_sync(_accessQueue, ^{
        selectedVirtualMachine = _roundRobinCounter % _max_tasks;
        _roundRobinCounter++;
    });

    JSContext* ctx;

    ctx = [[JSContext alloc] initWithVirtualMachine:_virtualMachines[selectedVirtualMachine]];

    unsigned long size;
    void* JS_SOURCE = getsectiondata(&_mh_execute_header, "__TEXT", "__acorn_src", &size);

    if (size == 0) {
        NSLog(@"Acorn is missing from the __TEXT segment");
    }

    NSString* src = [[NSString alloc] initWithBytesNoCopy:JS_SOURCE length:size encoding:NSUTF8StringEncoding freeWhenDone:NO];

    [ctx evaluateScript:src];
    [ctx evaluateScript:@"\
     function defined () {\
     for (var i = 0; i < arguments.length; i++) {\
     if (arguments[i] !== undefined) return arguments[i];\
     }}\
     function parse (src, opts) {\
     if (!opts) opts = {};\
     return acorn.parse(src, {\
     ecmaVersion: defined(opts.ecmaVersion, 6),\
     ranges: defined(opts.ranges, opts.range),\
     locations: defined(opts.locations, opts.loc),\
     allowReturnOutsideFunction: defined(\
     opts.allowReturnOutsideFunction, true\
     ),\
     strictSemicolons: defined(opts.strictSemicolons, false),\
     allowTrailingCommas: defined(opts.allowTrailingCommas, true),\
     forbidReserved: defined(opts.forbidReserved, false)\
     });\
     }"];

    ctx.exceptionHandler = ^(JSContext* context, JSValue* exception) {
        err = [NSError errorWithDomain:@"com.benng.paq" code:2 userInfo:@{NSLocalizedDescriptionKey: [exception toString]}];
    };

    // Remove hashbangs
    NSRegularExpression* regex = [NSRegularExpression regularExpressionWithPattern:@"^#![^\n]*\n" options:0 error:nil];
    code = [regex stringByReplacingMatchesInString:code options:0 range:NSMakeRange(0, [code length]) withTemplate:@""];

    JSValue* parseFunc = ctx[@"parse"];
    JSValue* evalResult = [parseFunc callWithArguments:@[ code ]];

    if (parseFunc == nil) {
        err = [NSError errorWithDomain:@"com.benng.paq" code:8 userInfo:@{ NSLocalizedDescriptionKey : @"A context without a parse function was given to Parser::parse" }];
    }

    ctx.exceptionHandler = nil;

    if (err) {
        if (error) {
            *error = err;
        }
        return nil;
    }

    if ([evalResult isObject]) {
        return [evalResult toDictionary];
    }
    else if ([evalResult isString]) {
        if (error) {
            *error = [NSError errorWithDomain:@"com.benng.paq" code:3 userInfo:@{ NSLocalizedDescriptionKey : [evalResult toString] }];
        }
    }
    else {
        if (error) {
            *error = [NSError errorWithDomain:@"com.benng.paq" code:4 userInfo:@{ NSLocalizedDescriptionKey : @"An unknown error occurred, there was no exception and an invalid return value from Acorn" }];
        }
    }

    return nil;
}

Parser::~Parser()
{
    dispatch_queue_t _accessQueue;
    [_virtualMachines removeAllObjects];
    _virtualMachines = nil;
    _accessQueue = nil;
}
