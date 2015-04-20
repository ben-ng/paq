//
//  transform.cpp
//  paq
//
//  Created by Ben on 3/27/15.
//  Copyright (c) 2015 Ben Ng. All rights reserved.
//

#import "transform.h"

/**
 * The transform string is a compiled transformer
 */
Transform::Transform(NSDictionary* options)
{
    // Parser contexts are JSContexts with acorn loaded up inside them
    _max_tasks = options != nil && options[@"maxTasks"] ? [options[@"maxTasks"] intValue] : 2;

    if (_max_tasks <= 0) {
        _max_tasks = 1;
    }

    _accessQueue = dispatch_queue_create("transform.serial", DISPATCH_QUEUE_SERIAL);
    _contextSema = dispatch_semaphore_create(_max_tasks);

    _contexts = [[NSMutableArray alloc] initWithCapacity:_max_tasks];
    _transformChain = options[@"transformChain"];

    for (NSUInteger i = 0; i < _max_tasks; ++i) {
        [_contexts addObject:createContext()];
    }
}

void Transform::transform(NSString* path, NSString* code, void (^callback)(NSError* error, NSString* source))
{
    dispatch_semaphore_wait(_contextSema, DISPATCH_TIME_FOREVER);

    dispatch_async(_accessQueue, ^{
        
        JSContext* ctx = _contexts.lastObject;
        [_contexts removeLastObject];
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
            // Remove hashbangs
            NSRegularExpression* regex = [NSRegularExpression regularExpressionWithPattern:@"^#![^\n]*\n" options:0 error:nil];
            NSString* newCode = [regex stringByReplacingMatchesInString:code options:0 range:NSMakeRange(0, [code length]) withTemplate:@""];
            
            ctx.exceptionHandler = ^(JSContext* context, JSValue* e) {
                NSLog(@"Transform Execution JS Error: %@", [e toString]);
            };
            
            ctx[@"transformCb"] = ^(JSValue* err, JSValue* transformedCode) {
                JSContext *currentContext = [PseudoBrowserJSContext currentContext];
                
                currentContext.exceptionHandler = nil;
                currentContext[@"transformCb"] = nil;
                
                NSString* errString = [err isNull] ? nil : [err toString];
                NSString* transformedCodeStr = errString == nil ? [transformedCode toString] : nil;
                
                dispatch_async(_accessQueue, ^{
                    
                    [_contexts addObject:currentContext];
                    
                    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
                        // Must signal first or someone might delete the Transform and release the semaphore while its still in use
                        dispatch_semaphore_signal(_contextSema);
                        
                        if (errString != nil) {
                            callback([NSError errorWithDomain:@"com.benng.paq" code:11 userInfo:@{ NSLocalizedDescriptionKey : errString }], nil);
                        }
                        else {
                            callback(nil, transformedCodeStr);
                        }
                    });
                });
            };
            
            [ctx evaluateScript:[NSString stringWithFormat:@"module.exports(%@, %@, transformCb)", JSONString(path), JSONString(newCode)]];
        });
    });
}

PseudoBrowserJSContext* Transform::createContext()
{
    NSString* wrappedBundle = [NSString stringWithFormat:@"var global = {}, exports = {}, module={exports:exports}; %@;", _transformChain];

    PseudoBrowserJSContext* ctx = [[PseudoBrowserJSContext alloc] init];

    ctx.exceptionHandler = ^(JSContext* ctx, JSValue* e) {
        NSLog(@"Transform Load JS Error: %@", [e toString]);
    };

    [ctx evaluateScript:wrappedBundle];

    return ctx;
}

Transform::Transform()
{
    _contextSema = nil;
    _accessQueue = nil;
    _transformChain = nil;
    [_contexts removeAllObjects];
    _contexts = nil;
}
