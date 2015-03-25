//
//  require.cpp
//  paq
//
//  Created by Ben on 3/25/15.
//  Copyright (c) 2015 Ben Ng. All rights reserved.
//

#import "require.h"

NSArray* Require::findRequires(JSContext *ctx, NSString *path, NSDictionary *ast, NSError **error) {
    __block NSMutableArray *modules = [[NSMutableArray alloc] initWithCapacity:10];
    
    Traverse::walk(ast, ^(NSDictionary *node) {
        if(!Require::isRequire(node))
            return;
        
        NSArray *args = (NSArray *) node[@"arguments"];
        
        if([args count]) {
            if([args[0][@"type"] isEqualToString:@"Literal"]) {
                [modules addObject:args[0][@"value"]];
            }
            else {
                __block bool errored = NO;
                
                ctx.exceptionHandler = ^(JSContext *context, JSValue *exception) {
                    NSString *errStr = [NSString stringWithFormat:@"JS Error compiling expression: %@", [exception toString]];
                    NSLog(@"%@", errStr);
                    
                    if(error) {
                        *error = [NSError errorWithDomain:@"com.benng.paq" code:2 userInfo:@{NSLocalizedDescriptionKey: errStr}];
                    }
                    
                    errored = YES;
                };
                
                JSValue *compiledEspression = [ctx[@"generate"] callWithArguments:@[args[0]]];
                
                if(!errored && [compiledEspression isString]) {
                    [modules addObject:[compiledEspression toString]];
                }
            }
        }
    });
    
    return modules;
};


JSContext* Require::createContext() {
    return Script::loadEmbeddedBundle("__escodegen_src", @"generate = escodegen.generate;");
};

bool Require::isRequire(NSDictionary *node) {
    NSDictionary *c = node[@"callee"];
    
    return c != nil &&
            [node[@"type"] isEqualToString:@"CallExpression"] &&
            [c[@"type"] isEqualToString:@"Identifier"] &&
            [c[@"name"] isEqualToString:@"require"];
}
