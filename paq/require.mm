//
//  require.mm
//  paq
//
//  Created by Ben on 3/25/15.
//  Copyright (c) 2015 Ben Ng. All rights reserved.
//

#import "require.h"

NSArray* Require::findRequires(JSContext* ctx, NSString* path, NSDictionary* ast, NSDictionary* options, NSError** error)
{
    __block NSMutableArray* modules = [[NSMutableArray alloc] initWithCapacity:10];
    __block NSMutableArray* errors = [[NSMutableArray alloc] init];
    __block bool errored = NO;

    Traverse::walk(ast, ^(NSDictionary* node) {
        if(errored) {
            return;
        }
        
        if(!Require::isRequire(node))
            return;
        
        __block NSError* err = nil;
        
        NSArray *args = (NSArray *) node[@"arguments"];
        
        if([args count]) {
            if([args[0][@"type"] isEqualToString:@"Literal"]) {
                [modules addObject:args[0][@"value"]];
            }
            else {
                
                ctx.exceptionHandler = ^(JSContext* context, JSValue* exception) {
                    NSString *errStr = [NSString stringWithFormat:@"JS Error %@ while compiling the expression: %@", [exception toString], path];
                    err = [NSError errorWithDomain:@"com.benng.paq" code:5 userInfo:@{NSLocalizedDescriptionKey: errStr}];
                };
                
                
                JSValue *compiledEspression = [ctx[@"generate"] callWithArguments:@[args[0]]];
                
                if(!err) {
                    // TODO: Also handle process.env since people like to use that
                    NSString *wrappedExpr = [NSString stringWithFormat:@"(function (path, __dirname, __filename) {return (%@)}(_path, %@, %@))", compiledEspression, JSONString([path stringByDeletingLastPathComponent]), JSONString(path)];
                    
                    ctx.exceptionHandler = ^(JSContext* context, JSValue* exception) {
                        NSString *errStr = [NSString stringWithFormat:@"JS Error %@ while evaluating the espression %@ in %@", [exception toString], compiledEspression, path];
                        err = [NSError errorWithDomain:@"com.benng.paq" code:9 userInfo:@{NSLocalizedDescriptionKey: errStr, NSLocalizedRecoverySuggestionErrorKey: @"Rerun with --ignoreUnresolvableExpressions to continue"}];
                    };
                    
                    JSValue *evaluatedExpression = [ctx evaluateScript:wrappedExpr];
                    
                    if(!err) {
                        if(![evaluatedExpression isString]) {
                            err = [NSError errorWithDomain:@"com.benng.paq" code:10 userInfo:@{NSLocalizedDescriptionKey: @"The evaluated expression did not result in a string value"}];
                        }
                        
                        if(!err && [compiledEspression isString]) {
                            [modules addObject:[evaluatedExpression toString]];
                        }
                    }
                }
            }
        }
        
        if(err) {
            if(err.code == 9 && !options[@"ignoreUnresolvableExpressions"]) {
                errored = YES;
            }
            
            [errors addObject:err];
        }
    });

    if (errored) {
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

JSContext* Require::createContext(NSString* pathModuleSrc)
{
    JSContext* ctx = Script::loadEmbeddedBundle("__escodegen_src", @"generate = escodegen.generate; global = {};");

    // This is a standalone browserify module, so it will appear at global.path
    [ctx evaluateScript:pathModuleSrc];

    // Move it to the path variable
    [ctx evaluateScript:@"_path = global.path; delete global.path; global = undefined;"];

    return ctx;
};

bool Require::isRequire(NSDictionary* node)
{
    NSDictionary* c = node[@"callee"];

    return c != nil &&
        [node[@"type"] isEqualToString:@"CallExpression"] &&
        [c[@"type"] isEqualToString:@"Identifier"] &&
        [c[@"name"] isEqualToString:@"require"];
}
