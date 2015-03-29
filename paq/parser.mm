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
    _max_tasks = options != nil && options[@"maxTasks"] ? [options[@"maxTasks"] intValue] : 4;

    if (_max_tasks <= 0) {
        _max_tasks = 1;
    }

    _accessQueue = dispatch_queue_create("parser.serial", DISPATCH_QUEUE_SERIAL);
    _contextSema = dispatch_semaphore_create(_max_tasks);

    _contexts = [[NSMutableArray alloc] initWithCapacity:_max_tasks];

    for (NSUInteger i = 0; i < _max_tasks; ++i) {
        [_contexts addObject:createContext()];
    }
}

void Parser::parse(NSString* code, void (^callback)(NSError* error, NSDictionary* ast, NSString* source))
{
    dispatch_semaphore_wait(_contextSema, DISPATCH_TIME_FOREVER);

    dispatch_async(_accessQueue, ^{
        
        JSContext* ctx = _contexts.lastObject;
        [_contexts removeLastObject];
        
        // No idea how this happens, but it does. Possibly when an exception happens.
        if([ctx globalObject] == nil) {
            ctx = createContext();
            [_contexts addObject:ctx];
        }

        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
            __block NSError *err = nil;
            
            ctx.exceptionHandler = ^(JSContext* context, JSValue* exception) {
                err = [NSError errorWithDomain:@"com.benng.paq" code:2 userInfo:@{NSLocalizedDescriptionKey: [exception toString]}];
            };
            
            // Remove hashbangs
            NSRegularExpression* regex = [NSRegularExpression regularExpressionWithPattern:@"^#![^\n]*\n" options:0 error:nil];
            NSString* newCode = [regex stringByReplacingMatchesInString:code options:0 range:NSMakeRange(0, [code length]) withTemplate:@""];
            
            JSValue* parseFunc = ctx[@"parse"];
            JSValue* evalResult = [parseFunc callWithArguments:@[ newCode ]];
            
            if (parseFunc == nil) {
                err = [NSError errorWithDomain:@"com.benng.paq" code:8 userInfo:@{ NSLocalizedDescriptionKey : @"A context without a parse function was given to Parser::parse" }];
            }
            
            ctx.exceptionHandler = nil;
            
            dispatch_async(_accessQueue, ^{
                
                [_contexts addObject:ctx];
                
                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
                    
                    if (err != nil) {
                        callback(err, nil, nil);
                    }
                    else {
                        if ([evalResult isObject]) {
                            callback(nil, [evalResult toDictionary], newCode);
                        }
                        else if ([evalResult isString]) {
                            callback([NSError errorWithDomain:@"com.benng.paq" code:3 userInfo:@{ NSLocalizedDescriptionKey : [evalResult toString] }], nil, nil);
                        }
                        else {
                            callback([NSError errorWithDomain:@"com.benng.paq" code:4 userInfo:@{ NSLocalizedDescriptionKey : @"An unknown error occurred, there was no exception and an invalid return value from Acorn" }], nil, nil);
                        }
                    }
                    
                    dispatch_semaphore_signal(_contextSema);
                });
            });
        });
    });
}

JSContext* Parser::createContext()
{
    JSContext* ctx = [[JSContext alloc] init];

    unsigned long size;
    void* JS_SOURCE = getsectiondata(&_mh_execute_header, "__TEXT", "__acorn_src", &size);

    if (size == 0) {
        NSLog(@"Acorn is missing from the __TEXT segment");
        exit(EXIT_FAILURE);
    }

    NSString* src = [[NSString alloc] initWithBytes:JS_SOURCE length:size encoding:NSUTF8StringEncoding];

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

    return ctx;
}

Parser::~Parser()
{
    _contextSema = nil;
    _accessQueue = nil;
    [_contexts removeAllObjects];
    _contexts = nil;
}
