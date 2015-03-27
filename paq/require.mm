//
//  require.mm
//  paq
//
//  Created by Ben on 3/25/15.
//  Copyright (c) 2015 Ben Ng. All rights reserved.
//

#import "require.h"

NSArray* Require::findRequires(JSContext* ctx, NSString* path, NSDictionary* ast, NSError** error)
{
    __block bool errored = NO;

    __block NSMutableArray* modules = [[NSMutableArray alloc] initWithCapacity:10];

    Traverse::walk(ast, ^(NSDictionary* node) {
        if(!Require::isRequire(node))
            return;
        
        NSArray *args = (NSArray *) node[@"arguments"];
        
        if([args count]) {
            if([args[0][@"type"] isEqualToString:@"Literal"]) {
                [modules addObject:args[0][@"value"]];
            }
            else {
                
                ctx.exceptionHandler = ^(JSContext* context, JSValue* exception) {
                    NSString *errStr = [NSString stringWithFormat:@"JS Error %@ while compiling the expression: %@", [exception toString], path];
                    NSLog(@"%@", errStr);
                    
                    if(error) {
                        *error = [NSError errorWithDomain:@"com.benng.paq" code:5 userInfo:@{NSLocalizedDescriptionKey: errStr}];
                    }
                    
                    errored = YES;
                };
                
                
                JSValue *compiledEspression = [ctx[@"generate"] callWithArguments:@[args[0]]];
                
                if(!errored) {
                    // TODO: Also handle process.env since people like to use that
                    NSString *wrappedExpr = [NSString stringWithFormat:@"(function (path, __dirname, __filename) {return (%@)}(_path, %@, %@))", compiledEspression, JSONString([path stringByDeletingLastPathComponent]), JSONString(path)];
                    
                    ctx.exceptionHandler = ^(JSContext* context, JSValue* exception) {
                        NSString *errStr = [NSString stringWithFormat:@"JS Error %@ while evaluating the espression %@ in %@", [exception toString], compiledEspression, path];
                        NSLog(@"%@", errStr);
                        
                        if(error) {
                            *error = [NSError errorWithDomain:@"com.benng.paq" code:5 userInfo:@{NSLocalizedDescriptionKey: errStr}];
                        }
                        
                        errored = YES;
                    };
                    
                    JSValue *evaluatedExpression = [ctx evaluateScript:wrappedExpr];
                    
                    if(!errored) {
                        if(![evaluatedExpression isString]) {
                            if(error) {
                                *error = [NSError errorWithDomain:@"com.benng.paq" code:10 userInfo:@{NSLocalizedDescriptionKey: @"The evaluated expression did not result in a string value"}];
                            }
                            
                            errored = YES;
                        }
                        
                        if(!errored && [compiledEspression isString]) {
                            [modules addObject:[evaluatedExpression toString]];
                        }
                    }
                }
            }
        }
    });

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
