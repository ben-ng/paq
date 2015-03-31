//
//  require.mm
//  paq
//
//  Created by Ben on 3/25/15.
//  Copyright (c) 2015 Ben Ng. All rights reserved.
//

#import "require.h"

Require::Require(NSDictionary* options)
{
    // Require contexts are JSContexts with acorn loaded up inside them
    _max_tasks = options != nil && options[@"maxTasks"] ? [options[@"maxTasks"] intValue] : 4;
    _ignore_unresolvable = options != nil && options[@"ignoreUnresolvableExpressions"] && [options[@"ignoreUnresolvableExpressions"] boolValue];

    if (_max_tasks <= 0) {
        _max_tasks = 1;
    }

    _pathSrc = Script::getNativeBuiltins()[@"path"];

    _accessQueue = dispatch_queue_create("require.serial", DISPATCH_QUEUE_SERIAL);
    _contextSema = dispatch_semaphore_create(_max_tasks);
    _contexts = [[NSMutableArray alloc] initWithCapacity:_max_tasks];

    for (NSUInteger i = 0; i < _max_tasks; ++i) {
        [_contexts addObject:createContext()];
    }
}

void Require::evaluateRequireExpressions(NSString* path, NSArray* expressions, void (^callback)(NSError* error, NSArray* requires))
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
            NSMutableArray *errors = [[NSMutableArray alloc] init];
            NSMutableArray *evaluated = [[NSMutableArray alloc] initWithCapacity:expressions.count];
            
            for (NSUInteger i = 0, ii = expressions.count; i < ii; ++i) {
                __block NSError* err = nil;
                
                NSString *expr = expressions[i];
                
                // TODO: Also handle process.env since people like to use that
                NSString* wrappedExpr = [NSString stringWithFormat:@"(function (path, __dirname, __filename) {return (%@)}(_path, %@, %@))", expr, JSONString([path stringByDeletingLastPathComponent]), JSONString(path)];
                
                ctx.exceptionHandler = ^(JSContext* context, JSValue* exception) {
                    if(!_ignore_unresolvable) {
                        NSString *errStr = [NSString stringWithFormat:@"JS Error %@ while evaluating the espression %@ in %@", [exception toString], expr, path];
                        err = [NSError errorWithDomain:@"com.benng.paq" code:9 userInfo:@{NSLocalizedDescriptionKey: errStr, NSLocalizedRecoverySuggestionErrorKey: @"Rerun with --ignoreUnresolvableExpressions to continue"}];
                    }
                };
                
                JSValue* evaluatedExpression = [ctx evaluateScript:wrappedExpr];
                
                ctx.exceptionHandler = nil;
                
                if (!err) {
                    if (![evaluatedExpression isString]) {
                        if (!_ignore_unresolvable) {
                            err = [NSError errorWithDomain:@"com.benng.paq" code:10 userInfo:@{ NSLocalizedDescriptionKey : @"The evaluated expression did not result in a string value" }];
                        }
                    }
                    else {
                        [evaluated addObject:[NSString stringWithString:[evaluatedExpression toString]]];
                    }
                }
                
                if (err) {
                    [errors addObject:err];
                }
            }
            
            dispatch_async(_accessQueue, ^{
                [_contexts addObject:ctx];
                
                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
                    if (errors.count > 0) {
                        // Merge together all our errors
                        NSMutableArray* errorDescs = [[NSMutableArray alloc] init];
                        
                        [errors enumerateObjectsUsingBlock:^(NSError* obj, NSUInteger idx, BOOL* stop) {
                            if(obj.localizedRecoverySuggestion) {
                                [errorDescs addObject:[NSString stringWithFormat:@"%@\n%@", obj.localizedDescription, obj.localizedRecoverySuggestion]];
                            }
                            else {
                                [errorDescs addObject:obj.localizedDescription];
                            }
                        }];
                        
                        NSString* compoundErrorDesc = [[NSMutableString alloc] initWithFormat:@"Unhandled errors encountered parsing requires:\n%@\n", [errorDescs componentsJoinedByString:@"\n"]];
                        NSError* compoundError = [NSError errorWithDomain:@"com.benng.paq" code:11 userInfo:@{ NSLocalizedDescriptionKey : compoundErrorDesc }];
                        
                        callback(compoundError, nil);
                    }
                    else {
                        callback(nil, evaluated);
                    }
                    
                    dispatch_semaphore_signal(_contextSema);
                });
            });
        });
    });
};

BOOL Require::isRequire(NSDictionary* node)
{
    NSDictionary* c = node[@"callee"];

    return c != nil &&
        [node[@"type"] isEqualToString:@"CallExpression"] &&
        [c[@"type"] isEqualToString:@"Identifier"] &&
        [c[@"name"] isEqualToString:@"require"];
}

JSContext* Require::createContext()
{
    JSContext* ctx;

    ctx = [[JSContext alloc] init];

    // This is a standalone browserify module, so it will appear at global.path
    [ctx evaluateScript:@"global = {}"];
    [ctx evaluateScript:_pathSrc];

    // Move it to the path variable
    [ctx evaluateScript:@"_path = global.path; delete global.path; global = undefined;"];

    return ctx;
}

Require::~Require()
{
    [_contexts removeAllObjects];
    _contexts = nil;
    _accessQueue = nil;
    _pathSrc = nil;
    _contextSema = nil;
}
