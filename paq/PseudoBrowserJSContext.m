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
        __weak PseudoBrowserJSContext* weakSelf = self;

        _handles = [[NSMutableDictionary alloc] init];

        NSArray* logFunctions = @[ @"log", @"info", @"warn", @"debug", @"error" ];

        self[@"setTimeout"] = ^(JSValue* function, JSValue* delay) {
            return [weakSelf setTimeout:function delay:delay];
        };

        self[@"setImmediate"] = ^(JSValue* function, JSValue* delay) {
            return [weakSelf setTimeout:function delay:delay];
        };

        self[@"setInterval"] = ^(JSValue* function, JSValue* delay) {
            return [weakSelf setInterval:function delay:delay];
        };

        self[@"clearTimeout"] = ^(JSValue* handle) {
            [weakSelf clearHandle:handle];
        };

        self[@"clearImmediate"] = ^(JSValue* handle) {
            [weakSelf clearHandle:handle];
        };

        self[@"clearInterval"] = ^(JSValue* handle) {
            [weakSelf clearHandle:handle];
        };

        // Fill in the console global with the functions people expect
        [self evaluateScript:@"console = {}"];

        for (NSUInteger i = 0, ii = logFunctions.count; i < ii; ++i) {
            [self evaluateScript:[NSString stringWithFormat:@"console.%@ = function noop(){}", logFunctions]];
        }
    }

    return self;
}

- (int)setTimeout:(JSValue*)function delay:(JSValue*)delay
{
    int currentHandle = _handle;
    __weak PseudoBrowserJSContext* weakSelf = self;

    _handles[[NSNumber numberWithInt:_handle]] = function;

    // Give each function a unique handle
    _handle++;

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)([delay toInt32] * NSEC_PER_MSEC)), dispatch_get_main_queue(), ^{
        JSValue *funcref = weakSelf.handles[[NSNumber numberWithInt:currentHandle]];
        
        // If the timeout was cleared, the function will be null when we want to call it
        if (![funcref isKindOfClass:NSNull.class]) {
            [funcref callWithArguments:@[]];
        }
    });

    return currentHandle;
}

- (int)setInterval:(JSValue*)function delay:(JSValue*)delay
{
    int currentHandle = _handle;
    int delayInt = [delay toInt32];
    __weak PseudoBrowserJSContext* weakSelf = self;

    _handles[[NSNumber numberWithInt:_handle]] = function;

    // Give each function a unique handle
    _handle++;

    __unsafe_unretained __block void (^iterationT)();
    void (^iteration)() = ^void() {
        // Immediately wait for the delay time
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInt * NSEC_PER_MSEC)), dispatch_get_main_queue(), ^{
            JSValue *funcref = weakSelf.handles[[NSNumber numberWithInt:currentHandle]];
            
            // If the timeout was cleared, the function will be null when we want to call it
            if (![funcref isKindOfClass:NSNull.class]) {
                [funcref callWithArguments:@[]];
                
                // Call it again later
                iterationT();
            }
        });
    };
    iterationT = iteration;
    iteration();

    return currentHandle;
}

- (void)clearHandle:(JSValue*)handle
{
    int handleInt = [handle toInt32];

    if (handleInt >= 0 && _handles[[NSNumber numberWithInt:handleInt]] != nil) {
        _handles[[NSNumber numberWithInt:handleInt]] = [NSNull null];
    }
}

- (void)dealloc
{
    [_handles removeAllObjects];
    _handles = nil;
}

@end
