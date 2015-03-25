//
//  main.cpp
//  paq-tests
//
//  Created by Ben on 3/23/15.
//  Copyright (c) 2015 Ben Ng. All rights reserved.
//

#define CATCH_CONFIG_MAIN  // This tells Catch to provide a main() - only do this in one cpp file
#import "catch.hpp"
#import "parser.h"
#import "traverse.h"
#import "require.h"
#import "resolve.h"
#import "paq.h"

/**
 * Parser
 */
TEST_CASE( "Parser returns a valid AST for valid code", "[parser]" ) {
    NSError *err;
    NSDictionary *ast = Parser::parse(Parser::createContext(), @"require(__dirname + 'path')", &err);
    
    REQUIRE(err == nil);
    REQUIRE(ast[@"type"] != nil);
    REQUIRE([ast[@"type"] isEqualToString:@"Program"]);
    REQUIRE([((NSArray *)ast[@"body"]) count] == 1);
    REQUIRE([((NSString *) ast[@"body"][0][@"type"]) isEqualToString: @"ExpressionStatement"]);
}

TEST_CASE( "Parser returns an error for invalid code", "[parser]" ) {
    NSError *err;
    NSDictionary *ast = Parser::parse(Parser::createContext(), @"var unbalanced = {", &err);
    
    REQUIRE(err != nil);
    REQUIRE([err.localizedDescription isEqualToString: @"SyntaxError: Unexpected token (1:18)"]);
    REQUIRE(ast == nil);
}

TEST_CASE( "Parser works on executable scripts", "[parser]" ) {
    NSError *err;
    NSDictionary *ast = Parser::parse(Parser::createContext(), @"#!/usr/local/bin/node\nrequire(__dirname + 'path')", &err);
    
    REQUIRE(err == nil);
    REQUIRE(ast[@"type"] != nil);
    REQUIRE([ast[@"type"] isEqualToString:@"Program"]);
    REQUIRE([((NSArray *)ast[@"body"]) count] == 1);
    REQUIRE([((NSString *) ast[@"body"][0][@"type"]) isEqualToString: @"ExpressionStatement"]);
}

/**
 * Traverse
 */

TEST_CASE( "Traverses an AST", "[traverse]" ) {
    NSError *err;
    NSDictionary *ast = Parser::parse(Parser::createContext(), @"require(__dirname + 'path')", &err);
    __block unsigned int nodeCounter = 0;
    
    Traverse::walk(ast, ^(NSObject *node) {
        nodeCounter++;
    });
    
    REQUIRE(nodeCounter == 7);
}

/**
 * Require
 */

TEST_CASE( "Extracts requires", "[require]" ) {
    NSError *err;
    NSDictionary *ast = Parser::parse(Parser::createContext(), @"require(__dirname + '/compound'); if(1) { require('tofu'); }", &err);
    
    REQUIRE(err == nil);
    
    NSArray *requires = Require::findRequires(Require::createContext(), @"/fake", ast, &err);
    
    REQUIRE([err localizedDescription] == nil);
    REQUIRE([requires count] == 2);
    REQUIRE([requires[0] isEqualToString:@"__dirname + '/compound'"]);
    REQUIRE([requires[1] isEqualToString:@"tofu"]);
}

/**
 * Resolve
 */

TEST_CASE( "Creates node_module paths", "[resolve]" ) {
    Resolve *resolver = new Resolve(nil);
    NSString* here = [[NSFileManager defaultManager] currentDirectoryPath];
    NSArray *paths = resolver->_nodeModulePaths(here);
    
    REQUIRE([paths count] > 1);
    REQUIRE([paths[0] hasSuffix:@"node_modules"]);
}

TEST_CASE( "Resolves lookup paths", "[resolve]" ) {
    Resolve *resolver = new Resolve(nil);
    NSString* here = [[NSFileManager defaultManager] currentDirectoryPath];
    NSMutableDictionary *parent = resolver->makeModuleStub(@"fixtures/index-js/entry.js");
    NSArray *paths = resolver->_resolveLookupPaths(@"lodash", parent);
    
    REQUIRE([paths count] == 2);
    REQUIRE([paths[1] count] > 6); // This should be pretty long
}

TEST_CASE( "Resolves relative file", "[resolve]" ) {
    Resolve *resolver = new Resolve(nil);
    NSString *here = [[NSFileManager defaultManager] currentDirectoryPath];
    NSMutableDictionary *parent = resolver->makeModuleStub(@"fixtures/index-js/entry.js");
    NSString *resolved = resolver->_resolveFilename(@"./mylib/index.js", parent);
    
    REQUIRE(resolved != nil);
    REQUIRE([resolved hasSuffix:@"/fixtures/index-js/mylib/index.js"]);
}

TEST_CASE( "Resolves relative directory", "[resolve]" ) {
    Resolve *resolver = new Resolve(nil);
    NSString *here = [[NSFileManager defaultManager] currentDirectoryPath];
    NSMutableDictionary *parent = resolver->makeModuleStub(@"fixtures/index-js/entry.js");
    NSString *resolved = resolver->_resolveFilename(@"./mylib", parent);
    
    REQUIRE(resolved != nil);
    REQUIRE([resolved hasSuffix:@"/fixtures/index-js/mylib/index.js"]);
}

TEST_CASE( "Resolves dependency with user defined main script", "[resolve]" ) {
    Resolve *resolver = new Resolve(nil);
    NSString *here = [[NSFileManager defaultManager] currentDirectoryPath];
    NSMutableDictionary *parent = resolver->makeModuleStub(@"fixtures/index-js/entry.js");
    NSString *resolved = resolver->_resolveFilename(@"waldo", parent);
    
    REQUIRE(resolved != nil);
    REQUIRE([resolved hasSuffix:@"/fixtures/index-js/node_modules/waldo/waldo/index.js"]);
}

TEST_CASE( "Resolves dependency by traversing upwards", "[resolve]" ) {
    Resolve *resolver = new Resolve(nil);
    NSString *here = [[NSFileManager defaultManager] currentDirectoryPath];
    NSMutableDictionary *parent = resolver->makeModuleStub(@"fixtures/index-js/entry.js");
    NSString *resolved = resolver->_resolveFilename(@"flamingo", parent);
    
    REQUIRE(resolved != nil);
    REQUIRE([resolved hasSuffix:@"/fixtures/node_modules/flamingo/flamingo.js"]);
}

TEST_CASE( "Resolves global", "[resolve]" ) {
    Resolve *resolver = new Resolve(nil);
    NSString *here = [[NSFileManager defaultManager] currentDirectoryPath];
    NSMutableDictionary *parent = resolver->makeModuleStub(@"fixtures/index-js/entry.js");
    NSString *resolved = resolver->_resolveFilename(@"http", parent);
    
    REQUIRE(resolved != nil);
    REQUIRE([resolved isEqualToString:@"http"]);
}

/**
 * paq: deps
 */

TEST_CASE( "Creates a dependency map", "[deps]" ) {
    Resolve *resolver = new Resolve(nil);
    NSString *here = [[NSFileManager defaultManager] currentDirectoryPath];
    NSMutableDictionary *parent = resolver->makeModuleStub(@"fixtures/index-js");
    Paq *paq = new Paq(@[resolver->path_resolve(@[here, @"fixtures/index-js/entry.js"])], nil);
    __block NSDictionary *dependencies;
    
    dispatch_semaphore_t sema = dispatch_semaphore_create(0);
    
    paq->deps(^(NSDictionary *deps) {
        dependencies = deps;
        dispatch_semaphore_signal(sema);
    });
    
    dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
    
    REQUIRE([dependencies count] == 4);
    
    [dependencies enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        NSString *sourceFile = (NSString *) key;
        NSDictionary *sourceData = (NSDictionary *) obj;
        NSDictionary *requirePairs = sourceData[@"deps"];
        
        REQUIRE(sourceData[@"source"] != nil);
        
        if([key hasSuffix:@"/index-js/entry.js"]) {
            REQUIRE([sourceData[@"entry"] boolValue] == YES);
            REQUIRE([requirePairs count] == 3);
            
            [requirePairs enumerateKeysAndObjectsUsingBlock:^(NSString *requireExpr, NSString *resolution, BOOL *stop) {
                if([requireExpr isEqualToString:@"./mylib"]) {
                    REQUIRE([resolution hasSuffix:@"/fixtures/index-js/mylib/index.js"]);
                }
                else if([requireExpr isEqualToString:@"waldo"]) {
                    REQUIRE([resolution hasSuffix:@"/fixtures/index-js/node_modules/waldo/waldo/index.js"]);
                }
                else if([requireExpr isEqualToString:@"flamingo"]) {
                    REQUIRE([resolution hasSuffix:@"/fixtures/node_modules/flamingo/flamingo.js"]);
                }
            }];
        }
        else {
            REQUIRE([sourceData[@"entry"] boolValue] == NO);
            REQUIRE([requirePairs count] == 0);
        }
    }];
}

/**
 * paq: bundle
 */

TEST_CASE( "Creates a bundle", "[bundle]" ) {
    Resolve *resolver = new Resolve(nil);
    NSString *here = [[NSFileManager defaultManager] currentDirectoryPath];
    NSMutableDictionary *parent = resolver->makeModuleStub(@"fixtures/index-js");
    NSString *entry = resolver->path_resolve(@[here, @"fixtures/index-js/entry.js"]);
    Paq *paq = new Paq(@[entry], nil);
    __block NSString *bundled;
    
    dispatch_semaphore_t semab = dispatch_semaphore_create(0);
    
    paq->bundle(@{@"eval": @YES}, ^(NSError *error, NSString *bundle) {
        bundled = bundle;
        dispatch_semaphore_signal(semab);
    });
    
    dispatch_semaphore_wait(semab, DISPATCH_TIME_FOREVER);
    
    REQUIRE(bundled != nil);
    
    JSContext *ctx = [[JSContext alloc] init];
    
    ctx.exceptionHandler = ^(JSContext *context, JSValue *exception) {
        NSLog(@"JS Error: %@", [exception toString]);
    };
    
    JSValue *result = [ctx evaluateScript:bundled];
    
    REQUIRE([[result toString] isEqualToString:@"Custom Lib You found waldo! flamingo"]);
 }
