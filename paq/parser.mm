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

void Parser::parse(NSString* code, void (^callback)(NSError* error, NSArray* literals, NSArray* expressions, NSString* source))
{
    dispatch_semaphore_wait(_contextSema, DISPATCH_TIME_FOREVER);

    dispatch_async(_accessQueue, ^{
        
        JSContext* ctx = _contexts.lastObject;
        [_contexts removeLastObject];
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
            __block NSError *err = nil;
            
            // Remove hashbangs
            NSRegularExpression* regex = [NSRegularExpression regularExpressionWithPattern:@"^#![^\n]*\n" options:0 error:nil];
            NSString* newCode = [regex stringByReplacingMatchesInString:code options:0 range:NSMakeRange(0, [code length]) withTemplate:@""];
            
            JSValue* parseFunc = ctx[@"detective"];
            
            ctx.exceptionHandler = ^(JSContext* context, JSValue* exception) {
                err = [NSError errorWithDomain:@"com.benng.paq" code:2 userInfo:@{NSLocalizedDescriptionKey: [exception toString]}];
            };
            
            JSValue* evalResult = [parseFunc callWithArguments:@[ newCode ]];
            
            ctx.exceptionHandler = nil;
            
            dispatch_async(_accessQueue, ^{
                
                [_contexts addObject:ctx];
                
                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
                    // Must signal first or someone might delete the Parser and release the semaphore while its still in use
                    dispatch_semaphore_signal(_contextSema);
                    
                    if (err != nil) {
                        callback(err, nil, nil, nil);
                    }
                    else {
                        if ([evalResult isObject]) {
                            NSDictionary *result = [evalResult toDictionary];
                            callback(nil, (NSArray *)result[@"strings"], (NSArray *)result[@"expressions"], newCode);
                        }
                        else if ([evalResult isString]) {
                            callback([NSError errorWithDomain:@"com.benng.paq" code:3 userInfo:@{ NSLocalizedDescriptionKey : [evalResult toString] }], nil, nil, nil);
                        }
                        else {
                            callback([NSError errorWithDomain:@"com.benng.paq" code:4 userInfo:@{ NSLocalizedDescriptionKey : @"An unknown error occurred, there was no exception and an invalid return value from Acorn" }], nil, nil, nil);
                        }
                    }
                });
            });
        });
    });
}

JSContext* Parser::createContext()
{
    JSContext* ctx = [[JSContext alloc] init];

    unsigned long size;
    void* JS_SOURCE = getsectiondata(&_mh_execute_header, "__TEXT", "__detective_src", &size);

    NSString* src = [[NSString alloc] initWithBytesNoCopy:JS_SOURCE length:size encoding:NSUTF8StringEncoding freeWhenDone:NO];

    [ctx evaluateScript:@"var exports = {}, module = {exports: exports};"];
    [ctx evaluateScript:src];
    [ctx evaluateScript:@"detective = module.exports.find "];

    return ctx;
}

Parser::~Parser()
{
    _contextSema = nil;
    _accessQueue = nil;
    [_contexts removeAllObjects];
    _contexts = nil;
}
