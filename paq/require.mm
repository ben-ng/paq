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
    _max_tasks = options != nil && options[@"maxTasks"] ? [options[@"maxTasks"] intValue] : 2;
    _ignore_unresolvable = options != nil && options[@"ignoreUnresolvableExpressions"] && [options[@"ignoreUnresolvableExpressions"] boolValue];

    if (_max_tasks <= 0) {
        _max_tasks = 1;
    }

    _pathSrc = Script::getNativeBuiltins()[@"path"];

    _accessQueue = dispatch_queue_create("require.serial", DISPATCH_QUEUE_SERIAL);
    _virtualMachines = [[NSMutableArray alloc] initWithCapacity:0];

    for (NSUInteger i = 0; i < _max_tasks; ++i) {
        [_virtualMachines addObject:[[JSVirtualMachine alloc] init]];
    }
}

NSArray* Require::findRequires(NSString* path, NSDictionary* ast, NSError** error)
{
    __block NSUInteger selectedVirtualMachine = 0;

    dispatch_sync(_accessQueue, ^{
        selectedVirtualMachine = _roundRobinCounter % _max_tasks;
        _roundRobinCounter++;
    });

    JSContext* ctx;

    ctx = [[JSContext alloc] initWithVirtualMachine:_virtualMachines[selectedVirtualMachine]];

    unsigned long size;
    void* JS_SOURCE = getsectiondata(&_mh_execute_header, "__TEXT", "__escodegen_src", &size);

    if (size == 0) {
        NSLog(@"Escodegen is missing from the __TEXT segment");
        exit(EXIT_FAILURE);
    }

    NSString* src = [[NSString alloc] initWithBytes:JS_SOURCE length:size encoding:NSUTF8StringEncoding];

    [ctx evaluateScript:src];

    [ctx evaluateScript:@"generate = escodegen.generate; global = {};"];

    // This is a standalone browserify module, so it will appear at global.path
    [ctx evaluateScript:_pathSrc];

    // Move it to the path variable
    [ctx evaluateScript:@"_path = global.path; delete global.path; global = undefined;"];

    // Context is set up, now to walk the AST and prepare work
    __block NSMutableArray* modules = [[NSMutableArray alloc] initWithCapacity:10];
    __block NSMutableArray* expressions = [[NSMutableArray alloc] initWithCapacity:10];
    NSMutableArray* errors = [[NSMutableArray alloc] init];

    Traverse::walk(ast, ^(NSDictionary* node) {
        if(!Require::isRequire(node))
            return;
        
        NSArray *args = (NSArray *) node[@"arguments"];
        
        if([args count]) {
            if([args[0][@"type"] isEqualToString:@"Literal"]) {
                [modules addObject:[NSString stringWithString:args[0][@"value"]]];
            }
            else {
                [expressions addObject:args[0]];
            }
        }
    });

    for (NSUInteger i = 0, ii = expressions.count; i < ii; ++i) {
        __block NSError* err = nil;

        ctx.exceptionHandler = ^(JSContext* context, JSValue* exception) {
            NSString *errStr = [NSString stringWithFormat:@"JS Error %@ while compiling the expression: %@", [exception toString], path];
            err = [NSError errorWithDomain:@"com.benng.paq" code:5 userInfo:@{NSLocalizedDescriptionKey: errStr}];
        };

        JSValue* compiledEspression = [ctx[@"generate"] callWithArguments:@[ expressions[i] ]];

        ctx.exceptionHandler = nil;

        if (!err) {
            // TODO: Also handle process.env since people like to use that
            NSString* wrappedExpr = [NSString stringWithFormat:@"(function (path, __dirname, __filename) {return (%@)}(_path, %@, %@))", compiledEspression, JSONString([path stringByDeletingLastPathComponent]), JSONString(path)];

            ctx.exceptionHandler = ^(JSContext* context, JSValue* exception) {
                if(!_ignore_unresolvable) {
                    NSString *errStr = [NSString stringWithFormat:@"JS Error %@ while evaluating the espression %@ in %@", [exception toString], compiledEspression, path];
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
                    [modules addObject:[NSString stringWithString:[evaluatedExpression toString]]];
                }
            }
        }

        if (err) {
            [errors addObject:err];
        }
    }

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

        if (error) {
            *error = compoundError;
        }
        else {
            NSLog(@"%@", compoundError);
        }

        return nil;
    }

    return modules;
};

BOOL Require::isRequire(NSDictionary* node)
{
    NSDictionary* c = node[@"callee"];

    return c != nil &&
        [node[@"type"] isEqualToString:@"CallExpression"] &&
        [c[@"type"] isEqualToString:@"Identifier"] &&
        [c[@"name"] isEqualToString:@"require"];
}

Require::~Require()
{
    dispatch_queue_t _accessQueue;
    [_virtualMachines removeAllObjects];
    _virtualMachines = nil;
    _accessQueue = nil;
    _pathSrc = nil;
}
