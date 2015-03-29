//
//  main.cpp
//  paq-tests
//
//  Created by Ben on 3/23/15.
//  Copyright (c) 2015 Ben Ng. All rights reserved.
//

#define CATCH_CONFIG_MAIN // This tells Catch to provide a main() - only do this in one cpp file
#import <Foundation/Foundation.h>
#import "json.h"
#import "JSContextExtensions.h"
#import "catch.hpp"
#import "parser.h"
#import "traverse.h"
#import "require.h"
#import "resolve.h"
#import "paq.h"

NSString* evaluateTransformSync(NSString* transformString, NSString* file, NSString* source)
{
    __block BOOL callbackWasCalled = NO;
    __block NSString* cbData = nil;
    JSContext* ctx = JSContextExtensions::create();

    NSString* wrappedBundle = [NSString stringWithFormat:@"var global = {}, exports = {}, module={exports:exports};%@;", transformString];

    ctx.exceptionHandler = ^(JSContext* ctx, JSValue* e) {
        NSLog(@"JS Error: %@", [e toString]);
    };

    [ctx evaluateScript:wrappedBundle];

    ctx[@"transformCb"] = ^(JSValue* err, JSValue* data) {
        cbData = [data toString];
        callbackWasCalled = YES;
    };

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [ctx evaluateScript:[NSString stringWithFormat:@"module.exports(%@, %@, transformCb)", JSONString(file), JSONString(source)]];
    });

    while (!callbackWasCalled) {
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]];
    }

    ctx.exceptionHandler = nil;

    return cbData;
}

/**
 * Parser
 */

TEST_CASE("Parser returns a valid AST for valid code", "[parser]")
{
    NSError* err = nil;
    Parser* parser = new Parser(nil);
    NSDictionary* ast = parser->parse(@"require(path.join(__dirname, 'path'))", &err);

    REQUIRE(err == nil);
    REQUIRE(ast[@"type"] != nil);
    REQUIRE([ast[@"type"] isEqualToString:@"Program"]);
    REQUIRE([((NSArray*)ast[@"body"])count] == 1);
    REQUIRE([((NSString*)ast[@"body"][0][@"type"])isEqualToString:@"ExpressionStatement"]);

    delete parser;
}

TEST_CASE("Parser returns an error for invalid code", "[parser]")
{
    NSError* err = nil;
    Parser* parser = new Parser(nil);
    NSDictionary* ast = parser->parse(@"var unbalanced = {", &err);

    REQUIRE(err != nil);
    REQUIRE([err.localizedDescription isEqualToString:@"SyntaxError: Unexpected token (1:18)"]);
    REQUIRE(ast == nil);

    delete parser;
}

TEST_CASE("Parser works on executable scripts", "[parser]")
{
    NSError* err = nil;
    Parser* parser = new Parser(nil);
    NSDictionary* ast = parser->parse(@"#!/usr/local/bin/node\nrequire(__dirname + 'path')", &err);

    REQUIRE(err == nil);
    REQUIRE(ast[@"type"] != nil);
    REQUIRE([ast[@"type"] isEqualToString:@"Program"]);
    REQUIRE([((NSArray*)ast[@"body"])count] == 1);
    REQUIRE([((NSString*)ast[@"body"][0][@"type"])isEqualToString:@"ExpressionStatement"]);

    delete parser;
}

/**
 * Traverse
 */

TEST_CASE("Traverses an AST", "[traverse]")
{
    NSError* err = nil;
    Parser* parser = new Parser(nil);
    NSDictionary* ast = parser->parse(@"require(__dirname + 'path')", &err);
    __block unsigned int nodeCounter = 0;

    Traverse::walk(ast, ^(NSObject* node) {
        nodeCounter++;
    });

    REQUIRE(nodeCounter == 7);

    delete parser;
}

/**
 * Require
 */

TEST_CASE("Extracts literal requires", "[require]")
{
    NSError* err = nil;
    Parser* parser = new Parser(nil);
    NSDictionary* ast = parser->parse(@"if(1) { require('tofu'); }", &err);

    REQUIRE(err == nil);

    NSArray* requires = Require::findRequires(Require::createContext(Paq::getNativeBuiltins()[@"path"]), @"/fakedir/somefile.js", ast, nil, &err);

    REQUIRE([err localizedDescription] == nil);
    REQUIRE([requires count] == 1);
    REQUIRE([requires[0] isEqualToString:@"tofu"]);

    delete parser;
}

TEST_CASE("Evaluates require expressions with the path module available", "[require]")
{
    NSError* err = nil;
    Parser* parser = new Parser(nil);
    NSDictionary* ast = parser->parse(@"'use unstrict'; require(path.join(__dirname, 'compound'));", &err);

    REQUIRE(err == nil);

    NSArray* requires = Require::findRequires(Require::createContext(Paq::getNativeBuiltins()[@"path"]), @"/fakedir/somefile.js", ast, nil, &err);

    REQUIRE([err localizedDescription] == nil);
    REQUIRE([requires count] == 1);
    REQUIRE([requires[0] isEqualToString:@"/fakedir/compound"]);

    delete parser;
}

/**
 * Resolve
 */

TEST_CASE("Creates node_module paths", "[resolve]")
{
    Resolve* resolver = new Resolve(@{ @"nativeModules" : (Paq::getNativeBuiltins()) });
    NSString* here = [[NSFileManager defaultManager] currentDirectoryPath];
    NSArray* paths = resolver->_nodeModulePaths(here);

    REQUIRE([paths count] > 1);
    REQUIRE([paths[0] hasSuffix:@"node_modules"]);

    delete resolver;
}

TEST_CASE("Resolves lookup paths", "[resolve]")
{
    Resolve* resolver = new Resolve(@{ @"nativeModules" : (Paq::getNativeBuiltins()) });
    NSString* here = [[NSFileManager defaultManager] currentDirectoryPath];
    NSMutableDictionary* parent = resolver->makeModuleStub(@"fixtures/basic/entry.js");
    NSArray* paths = resolver->_resolveLookupPaths(@"lodash", parent);

    REQUIRE([paths count] == 2);
    REQUIRE([paths[1] count] > 6); // This should be pretty long

    delete resolver;
}

TEST_CASE("Resolves relative file", "[resolve]")
{
    Resolve* resolver = new Resolve(@{ @"nativeModules" : (Paq::getNativeBuiltins()) });
    NSString* here = [[NSFileManager defaultManager] currentDirectoryPath];
    NSMutableDictionary* parent = resolver->makeModuleStub(@"fixtures/basic/entry.js");
    NSString* resolved = resolver->_resolveFilename(@"./mylib/index.js", parent);

    REQUIRE(resolved != nil);
    REQUIRE([resolved hasSuffix:@"/fixtures/basic/mylib/index.js"]);

    delete resolver;
}

TEST_CASE("Resolves relative directory", "[resolve]")
{
    Resolve* resolver = new Resolve(@{ @"nativeModules" : (Paq::getNativeBuiltins()) });
    NSString* here = [[NSFileManager defaultManager] currentDirectoryPath];
    NSMutableDictionary* parent = resolver->makeModuleStub(@"fixtures/basic/entry.js");
    NSString* resolved = resolver->_resolveFilename(@"./mylib", parent);

    REQUIRE(resolved != nil);
    REQUIRE([resolved hasSuffix:@"/fixtures/basic/mylib/index.js"]);

    delete resolver;
}

TEST_CASE("Resolves dependency with user defined main script", "[resolve]")
{
    Resolve* resolver = new Resolve(@{ @"nativeModules" : (Paq::getNativeBuiltins()) });
    NSString* here = [[NSFileManager defaultManager] currentDirectoryPath];
    NSMutableDictionary* parent = resolver->makeModuleStub(@"fixtures/basic/entry.js");
    NSString* resolved = resolver->_resolveFilename(@"waldo", parent);

    REQUIRE(resolved != nil);
    REQUIRE([resolved hasSuffix:@"/fixtures/basic/node_modules/waldo/waldo/index.js"]);

    delete resolver;
}

TEST_CASE("Resolves dependency by traversing upwards", "[resolve]")
{
    Resolve* resolver = new Resolve(@{ @"nativeModules" : (Paq::getNativeBuiltins()) });
    NSString* here = [[NSFileManager defaultManager] currentDirectoryPath];
    NSMutableDictionary* parent = resolver->makeModuleStub(@"fixtures/basic/entry.js");
    NSString* resolved = resolver->_resolveFilename(@"flamingo", parent);

    REQUIRE(resolved != nil);
    REQUIRE([resolved hasSuffix:@"/fixtures/node_modules/flamingo/flamingo.js"]);

    delete resolver;
}

TEST_CASE("Resolves relative dependency by traversing upwards multiple directories", "[resolve]")
{
    Resolve* resolver = new Resolve(@{ @"nativeModules" : (Paq::getNativeBuiltins()) });
    NSString* here = [[NSFileManager defaultManager] currentDirectoryPath];
    NSMutableDictionary* parent = resolver->makeModuleStub(@"fixtures/basic/deep/deeper/deepest/bottom.js");
    NSString* resolved = resolver->_resolveFilename(@"../../../json", parent);

    REQUIRE(resolved != nil);
    REQUIRE([resolved hasSuffix:@"/fixtures/basic/json.json"]);

    delete resolver;
}

TEST_CASE("Resolves global", "[resolve]")
{
    Resolve* resolver = new Resolve(@{ @"nativeModules" : (Paq::getNativeBuiltins()) });
    NSString* here = [[NSFileManager defaultManager] currentDirectoryPath];
    NSMutableDictionary* parent = resolver->makeModuleStub(@"fixtures/basic/entry.js");
    NSString* resolved = resolver->_resolveFilename(@"http", parent);

    REQUIRE(resolved != nil);
    REQUIRE([resolved isEqualToString:@"http"]);

    delete resolver;
}

/**
 * paq: deps

TEST_CASE("Creates a dependency map", "[deps]")
{
    Paq* paq = new Paq(@[ @"fixtures/basic/entry.js" ], nil);
    __block NSDictionary* dependencies;

    dispatch_semaphore_t sema = dispatch_semaphore_create(0);

    paq->deps(^(NSDictionary* deps) {
        dependencies = deps;
        dispatch_semaphore_signal(sema);
    });

    dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);

    REQUIRE(dependencies != nil);
    REQUIRE([dependencies count] == 7);

    [dependencies enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL* stop) {
        NSString *sourceFile = (NSString *) key;
        NSDictionary *sourceData = (NSDictionary *) obj;
        NSDictionary *requirePairs = sourceData[@"deps"];
        
        REQUIRE(sourceData[@"source"] != nil);
        
        if([key hasSuffix:@"/basic/entry.js"]) {
            REQUIRE([sourceData[@"entry"] boolValue] == YES);
            REQUIRE([requirePairs count] == 5);
            
            [requirePairs enumerateKeysAndObjectsUsingBlock:^(NSString *requireExpr, NSString *resolution, BOOL *stop) {
                if([requireExpr isEqualToString:@"./mylib"]) {
                    REQUIRE([resolution hasSuffix:@"/fixtures/basic/mylib/index.js"]);
                }
                else if([requireExpr isEqualToString:@"waldo"]) {
                    REQUIRE([resolution hasSuffix:@"/fixtures/basic/node_modules/waldo/waldo/index.js"]);
                }
                else if([requireExpr isEqualToString:@"flamingo"]) {
                    REQUIRE([resolution hasSuffix:@"/fixtures/node_modules/flamingo/flamingo.js"]);
                }
                else if([requireExpr isEqualToString:@"flamingo/package"]) {
                    REQUIRE([resolution hasSuffix:@"/fixtures/node_modules/flamingo/package.json"]);
                }
                else if([requireExpr isEqualToString:@"./deep/deeper/deepest/bottom"]) {
                    REQUIRE([resolution hasSuffix:@"/fixtures/basic/deep/deeper/deepest/bottom.js"]);
                }
            }];
        }
        else if([key hasSuffix:@"/basic/deep/deeper/deepest/bottom.js"]) {
            REQUIRE([sourceData[@"entry"] boolValue] == NO);
            REQUIRE([requirePairs count] == 1);
            REQUIRE([requirePairs[@"../../../json"] hasSuffix:@"/fixtures/basic/json.json"]);
        }
        else {
            REQUIRE([sourceData[@"entry"] boolValue] == NO);
            REQUIRE([requirePairs count] == 0);
        }
    }];

    std::cout << "Test I destroying Resolve" << std::endl;
    delete resolver;
    std::cout << "Test I destroyed Resolve" << std::endl;

    std::cout << "Test I destroying Paq" << std::endl;
    delete paq;
    std::cout << "Test I destroyed Paq" << std::endl;
 }
 */

/**
 * paq: bundle

TEST_CASE("Creates a basic bundle", "[bundle]")
{
    Paq* paq = new Paq(@[ @"fixtures/basic/entry.js" ], nil);
    REQUIRE([paq->evalToString() isEqualToString:@"Custom Lib You found waldo! flamingo fishing flamingo.js"]);

    std::cout << "Test J destroying Paq" << std::endl;
    delete paq;
    std::cout << "Test J destroyed Paq" << std::endl;
}

TEST_CASE("Creates a basic bundle without concurrency", "[bundle]")
{
    Paq* paq = new Paq(@[ @"fixtures/basic/entry.js" ], @{ @"parserTasks" : [NSNumber numberWithInt:1],
        @"requireTasks" : [NSNumber numberWithInt:1] });
    REQUIRE([paq->evalToString() isEqualToString:@"Custom Lib You found waldo! flamingo fishing flamingo.js"]);

    std::cout << "Test K destroying Paq" << std::endl;
    delete paq;
    std::cout << "Test K destroyed Paq" << std::endl;
}

TEST_CASE("Converts the hbsfy transform", "[bundle]")
{
    Paq* paq = new Paq(@[ @"fixtures/node_modules/hbsfy/index.js" ], @{ @"ignoreUnresolvableExpressions" : [NSNumber numberWithBool:YES] });
    NSError* err = nil;
    NSString* bundle = paq->bundleSync(@{ @"convertBrowserifyTransform" : [NSNumber numberWithBool:YES] }, &err);

    // Should have the hbsfy runtime somewhere in it
    REQUIRE([bundle rangeOfString:@"require('hbsfy/runtime')"].location != NSNotFound);

    NSString* evaluated = evaluateTransformSync(bundle, @"hbs", @"My name is {{name}}");

    REQUIRE(evaluated != nil);
    REQUIRE([evaluated rangeOfString:@"return \"My name is \""].location != NSNotFound);

    std::cout << "Test L destroying Paq" << std::endl;
    delete paq;
    std::cout << "Test L destroyed Paq" << std::endl;
}

TEST_CASE("Converts the babelify transform", "[bundle]")
{
    Paq* paq = new Paq(@[ @"fixtures/node_modules/babelify/index.js" ], @{ @"ignoreUnresolvableExpressions" : [NSNumber numberWithBool:YES] });
    NSError* err = nil;
    NSString* bundle = paq->bundleSync(@{ @"convertBrowserifyTransform" : [NSNumber numberWithBool:YES] }, &err);

    // Should have references to JSX stuff somewhere in it
    REQUIRE([bundle rangeOfString:@"JSXElement"].location != NSNotFound);

    NSString* evaluated = evaluateTransformSync(bundle, @"hello.jsx", @"<div>Hello {this.props.name}</div>;");

    REQUIRE(evaluated != nil);
    REQUIRE([evaluated rangeOfString:@"React.createElement("].location != NSNotFound);

    std::cout << "Test M destroying Paq" << std::endl;
    delete paq;
    std::cout << "Test M destroyed Paq" << std::endl;
}

TEST_CASE("Bundles node core modules", "[bundle]")
{
    Paq* paq = new Paq(@[ @"fixtures/node-core/index.js" ], nil);
    REQUIRE([paq->evalToString() isEqualToString:@"a/b"]);

    std::cout << "Test N destroying Paq" << std::endl;
    delete paq;
    std::cout << "Test N destroyed Paq" << std::endl;
}

TEST_CASE("Inserts module globals", "[bundle]")
{
    Paq* paq = new Paq(@[ @"fixtures/insert-globals/index.js" ], nil);
    REQUIRE([paq->evalToString() hasSuffix:@"insert-globals"]);

    std::cout << "Test O destroying Paq" << std::endl;
    delete paq;
    std::cout << "Test O destroyed Paq" << std::endl;
}

TEST_CASE("Ignores unevaluated expressions", "[bundle]")
{
    // There is something like a require(opts.p || opts.default) in hbsfy. If this test passes, then the option was respected
    Paq* paq = new Paq(@[ @"fixtures/node_modules/hbsfy/index.js" ], @{ @"ignoreUnresolvableExpressions" : [NSNumber numberWithBool:YES] });
    NSError* err = nil;
    NSString* bundle = paq->bundleSync(nil, &err);
    REQUIRE(err == nil);
    REQUIRE([bundle lengthOfBytesUsingEncoding:NSUTF8StringEncoding] > 0);

    std::cout << "Test P destroying Paq" << std::endl;
    delete paq;
    std::cout << "Test P destroyed Paq" << std::endl;
 }
 */

/*
TEST_CASE("Uses hbsfy transform", "[bundle]")
{
    // There is something like a require(opts.p || opts.default) in hbsfy. If this test passes, then the option was respected
    Paq* paq = new Paq(@[ @"fixtures/hbs-app/index.js" ], @{ @"ignoreUnresolvableExpressions" : [NSNumber numberWithBool:YES],
        @"transforms" : @[ @"hbsfy" ] });

    NSError* err = nil;
    NSString* bundle = paq->bundleSync(nil, &error);
    REQUIRE(error == nil);
    REQUIRE([bundle lengthOfBytesUsingEncoding:NSUTF8StringEncoding] > 0);
    REQUIRE([paq->evalToString() isEqualToString:@"Hello World!"]);
}
*/

/*
TEST_CASE("Wait for instruments to detect leaks", "[instruments]")
{
    [NSThread sleepForTimeInterval:1.0f];
    [NSThread sleepForTimeInterval:1.0f];
    [NSThread sleepForTimeInterval:1.0f];
    [NSThread sleepForTimeInterval:1.0f];
    [NSThread sleepForTimeInterval:1.0f];
    [NSThread sleepForTimeInterval:1.0f];
    [NSThread sleepForTimeInterval:1.0f];
    [NSThread sleepForTimeInterval:1.0f];
    [NSThread sleepForTimeInterval:1.0f];
    [NSThread sleepForTimeInterval:1.0f];
    REQUIRE(1 == 1);
}*/
