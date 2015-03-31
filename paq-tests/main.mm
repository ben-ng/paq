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
#import "require.h"
#import "resolve.h"
#import "pack.h"
#import "paq.h"

/**
 * Executes the parser method synchronously and returns the array @[ error, ast, source ]
 */
NSArray* parseSync(NSString* input)
{
    Parser* parser = new Parser(nil);
    __block NSArray* cbData = nil;
    dispatch_semaphore_t sema = dispatch_semaphore_create(0);

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        parser->parse(input, ^(NSError *error, NSArray *literals, NSArray *expressions, NSString *source) {
            cbData = @[error != nil ? error : [NSNull null], literals != nil ? literals : [NSNull null], expressions != nil ? expressions : [NSNull null], source != nil ? source : [NSNull null]];
            
            dispatch_semaphore_signal(sema);
        });
    });

    dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
    delete parser;

    return cbData;
}

/**
 * Executes the require method synchronously and returns the array @[ error, requires ]
 */
NSArray* requireSync(NSString* path, NSArray* expressions)
{
    Require* require = new Require(nil);
    __block NSArray* cbData = nil;
    dispatch_semaphore_t sema = dispatch_semaphore_create(0);

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        require->evaluateRequireExpressions(path, expressions, ^(NSError *error, NSArray *requires) {
            cbData = @[error != nil ? error : [NSNull null], requires != nil ? requires : [NSNull null]];
            
            dispatch_semaphore_signal(sema);
        });
    });

    dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
    delete require;

    return cbData;
}

NSString* evaluateTransformSync(NSString* transformString, NSString* file, NSString* source)
{
    __block BOOL callbackWasCalled = NO;
    __block NSString* cbData = nil;

    NSString* wrappedBundle = [NSString stringWithFormat:@"var global = {}, exports = {}, module={exports:exports};%@;", transformString];

    JSContext* ctx = JSContextExtensions::create();

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
    ctx[@"transformCb"] = nil;

    JSContextExtensions::destroy(ctx);

    ctx = nil;

    return cbData;
}

/**
 * Parser
 */

TEST_CASE("Parser returns require statements for valid code", "[parser]")
{
    NSArray* result = parseSync(@"require('taco') && require(path.join(__dirname, 'path'))");
    NSError* err = result[0];
    NSArray* literals = result[1];
    NSArray* expressions = result[2];

    REQUIRE([err isKindOfClass:NSNull.class]);
    REQUIRE(literals.count == 1);
    REQUIRE([literals[0] isEqualToString:@"taco"]);
    REQUIRE(expressions.count == 1);
    REQUIRE([expressions[0] isEqualToString:@"path.join(__dirname, 'path')"]);
}

TEST_CASE("Parser returns an error for invalid code", "[parser]")
{
    // MUST have "require" somewhere in the string because node-detective cheats!
    NSArray* result = parseSync(@"var unbalanced = {this [][] is not !! valid @#@#$ code require");
    NSError* err = result[0];
    NSArray* literals = result[1];
    NSArray* expressions = result[2];
    NSString* source = result[3];

    REQUIRE(![err isKindOfClass:NSNull.class]);
    REQUIRE([err.localizedDescription isEqualToString:@"SyntaxError: Unexpected token (1:23)"]);
    REQUIRE([literals isKindOfClass:NSNull.class]);
    REQUIRE([expressions isKindOfClass:NSNull.class]);
    REQUIRE([source isKindOfClass:NSNull.class]);
}

TEST_CASE("Parser works on executable scripts", "[parser]")
{
    NSArray* result = parseSync(@"#!/usr/local/bin/node\nrequire(__dirname + 'path')");
    NSError* err = result[0];
    NSArray* literals = result[1];
    NSArray* expressions = result[2];
    NSString* source = result[3];

    REQUIRE([err isKindOfClass:NSNull.class]);
    REQUIRE(literals.count == 0);
    REQUIRE(expressions.count == 1);
    REQUIRE([expressions[0] isEqualToString:@"__dirname + 'path'"]);
    REQUIRE(source.length > 0);
}

TEST_CASE("Extracts literal requires", "[parse]")
{
    NSError* err = nil;

    NSArray* result = parseSync(@"require('tofu')");

    REQUIRE([result[0] isKindOfClass:NSNull.class]);

    NSArray* literals = result[1];

    err = result[0];

    REQUIRE([err isKindOfClass:NSNull.class]);
    REQUIRE([literals count] == 1);
    REQUIRE([literals[0] isEqualToString:@"tofu"]);
}

/**
 * Require
 */

TEST_CASE("Evaluates require expressions with the path module available", "[parse]")
{
    NSError* err = nil;

    NSArray* result = parseSync(@"'use unstrict'; require(path.join(__dirname, 'compound'));");
    err = result[0];
    NSArray* expressions = result[2];

    REQUIRE([err isKindOfClass:NSNull.class]);

    Require* require = new Require(nil);

    err = nil;
    NSArray* results = requireSync(@"/fakedir/somefile.js", expressions);
    err = results[0];
    NSArray* requires = results[1];

    REQUIRE([err isKindOfClass:NSNull.class]);
    REQUIRE([requires count] == 1);
    REQUIRE([requires[0] isEqualToString:@"/fakedir/compound"]);
}

TEST_CASE("Fails to resolve expressions with arbitrary variables", "[require]")
{
    NSError* err = nil;

    NSArray* result = parseSync(@"require(opts.puppy)");
    err = result[0];
    NSArray* expressions = result[2];

    REQUIRE([err isKindOfClass:NSNull.class]);

    Require* require = new Require(nil);

    err = nil;
    NSArray* results = requireSync(@"/fakedir/somefile.js", expressions);
    err = results[0];
    NSArray* requires = results[1];

    REQUIRE(![err isKindOfClass:NSNull.class]);
    REQUIRE(err.code == 11);
    // Should say what the problem is
    REQUIRE([err.localizedDescription rangeOfString:@"Can't find variable: opts"].location != NSNotFound);
    // Should give a recovery option
    REQUIRE([err.localizedDescription rangeOfString:@"Rerun with --ignoreUnresolvableExpressions to continue"].location != NSNotFound);
}

/**
 * Resolve
 */

TEST_CASE("Creates node_module paths", "[resolve]")
{
    Resolve* resolver = new Resolve(nil);
    NSString* here = [[NSFileManager defaultManager] currentDirectoryPath];
    NSArray* paths = resolver->_nodeModulePaths(here);

    REQUIRE([paths count] > 1);
    REQUIRE([paths[0] hasSuffix:@"node_modules"]);

    delete resolver;
}

TEST_CASE("Resolves lookup paths", "[resolve]")
{
    Resolve* resolver = new Resolve(nil);
    NSString* here = [[NSFileManager defaultManager] currentDirectoryPath];
    NSMutableDictionary* parent = resolver->makeModuleStub(@"fixtures/basic/entry.js");
    NSArray* paths = resolver->_resolveLookupPaths(@"lodash", parent);

    REQUIRE([paths count] == 2);
    REQUIRE([paths[1] count] > 6); // This should be pretty long

    delete resolver;
}

TEST_CASE("Resolves relative file", "[resolve]")
{
    Resolve* resolver = new Resolve(nil);
    NSString* here = [[NSFileManager defaultManager] currentDirectoryPath];
    NSMutableDictionary* parent = resolver->makeModuleStub(@"fixtures/basic/entry.js");
    NSString* resolved = resolver->_resolveFilename(@"./mylib/index.js", parent, nil);

    REQUIRE(resolved != nil);
    REQUIRE([resolved hasSuffix:@"/fixtures/basic/mylib/index.js"]);

    delete resolver;
}

TEST_CASE("Resolves relative directory", "[resolve]")
{
    Resolve* resolver = new Resolve(nil);
    NSString* here = [[NSFileManager defaultManager] currentDirectoryPath];
    NSMutableDictionary* parent = resolver->makeModuleStub(@"fixtures/basic/entry.js");
    NSString* resolved = resolver->_resolveFilename(@"./mylib", parent, nil);

    REQUIRE(resolved != nil);
    REQUIRE([resolved hasSuffix:@"/fixtures/basic/mylib/index.js"]);

    delete resolver;
}

TEST_CASE("Resolves dependency with user defined main script", "[resolve]")
{
    Resolve* resolver = new Resolve(nil);
    NSString* here = [[NSFileManager defaultManager] currentDirectoryPath];
    NSMutableDictionary* parent = resolver->makeModuleStub(@"fixtures/basic/entry.js");
    NSString* resolved = resolver->_resolveFilename(@"waldo", parent, nil);

    REQUIRE(resolved != nil);
    REQUIRE([resolved hasSuffix:@"/fixtures/basic/node_modules/waldo/waldo/index.js"]);

    delete resolver;
}

TEST_CASE("Resolves dependency by traversing upwards", "[resolve]")
{
    Resolve* resolver = new Resolve(nil);
    NSString* here = [[NSFileManager defaultManager] currentDirectoryPath];
    NSMutableDictionary* parent = resolver->makeModuleStub(@"fixtures/basic/entry.js");
    NSString* resolved = resolver->_resolveFilename(@"flamingo", parent, nil);

    REQUIRE(resolved != nil);
    REQUIRE([resolved hasSuffix:@"/fixtures/node_modules/flamingo/flamingo.js"]);

    delete resolver;
}

TEST_CASE("Resolves relative dependency by traversing upwards multiple directories", "[resolve]")
{
    Resolve* resolver = new Resolve(nil);
    NSString* here = [[NSFileManager defaultManager] currentDirectoryPath];
    NSMutableDictionary* parent = resolver->makeModuleStub(@"fixtures/basic/deep/deeper/deepest/bottom.js");
    NSString* resolved = resolver->_resolveFilename(@"../../../json", parent, nil);

    REQUIRE(resolved != nil);
    REQUIRE([resolved hasSuffix:@"/fixtures/basic/json.json"]);

    delete resolver;
}

TEST_CASE("Resolves global", "[resolve]")
{
    Resolve* resolver = new Resolve(nil);
    NSString* here = [[NSFileManager defaultManager] currentDirectoryPath];
    NSMutableDictionary* parent = resolver->makeModuleStub(@"fixtures/basic/entry.js");
    NSString* resolved = resolver->_resolveFilename(@"http", parent, nil);

    REQUIRE(resolved != nil);
    REQUIRE([resolved isEqualToString:@"http"]);

    delete resolver;
}

TEST_CASE("Should error on missing module", "[resolve]")
{
    Resolve* resolver = new Resolve(nil);
    NSString* here = [[NSFileManager defaultManager] currentDirectoryPath];
    NSMutableDictionary* parent = resolver->makeModuleStub(@"fixtures/basic/entry.js");
    NSError* error = nil;
    NSString* resolved = resolver->_resolveFilename(@"i-dont-exist!", parent, &error);

    REQUIRE(resolved == nil);
    REQUIRE(error != nil);
    REQUIRE([error.localizedDescription rangeOfString:@"tried:"].location != NSNotFound);

    delete resolver;
}

/**
 * paq: deps
 */

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

    delete paq;
}

/**
 * paq: pack errors
 */

TEST_CASE("Eval cannot be used with more than one entry script")
{
    Pack::pack(@[ @"a", @"b" ], nil, @{ @"eval" : [NSNumber numberWithBool:YES] },
        ^(NSError* error, NSString* bundle) {
        REQUIRE(error != nil);
        });
}

TEST_CASE("Standalone cannot be used with more than one entry script")
{
    Pack::pack(@[ @"a", @"b" ], nil, @{ @"standalone" : [NSNumber numberWithBool:YES] },
        ^(NSError* error, NSString* bundle) {
                   REQUIRE(error != nil);
        });
}

TEST_CASE("ConvertBrowserifyTransform cannot be used with more than one entry script")
{
    Pack::pack(@[ @"a", @"b" ], nil, @{ @"standalone" : [NSNumber numberWithBool:YES] },
        ^(NSError* error, NSString* bundle) {
                   REQUIRE(error != nil);
        });
}

/**
 * paq: bundle
 */

TEST_CASE("Creates a basic bundle", "[bundle]")
{
    Paq* paq = new Paq(@[ @"fixtures/basic/entry.js" ], nil);
    REQUIRE([paq->evalToString() isEqualToString:@"Custom Lib You found waldo! flamingo fishing flamingo.js"]);

    delete paq;
}

TEST_CASE("Creates a basic bundle without concurrency", "[bundle]")
{
    Paq* paq = new Paq(@[ @"fixtures/basic/entry.js" ], @{ @"parserTasks" : [NSNumber numberWithInt:1],
        @"requireTasks" : [NSNumber numberWithInt:1] });
    REQUIRE([paq->evalToString() isEqualToString:@"Custom Lib You found waldo! flamingo fishing flamingo.js"]);

    delete paq;
}

TEST_CASE("Bundles node core modules", "[bundle]")
{
    Paq* paq = new Paq(@[ @"fixtures/node-core/index.js" ], nil);
    NSString* evaled = paq->evalToString();
    REQUIRE([evaled isEqualToString:@"a/b"]);

    delete paq;
}

TEST_CASE("Inserts module globals", "[bundle]")
{
    Paq* paq = new Paq(@[ @"fixtures/insert-globals/index.js" ], nil);
    NSString* evaled = paq->evalToString();
    REQUIRE([evaled hasSuffix:@"insert-globals/browser"]);

    delete paq;
}

TEST_CASE("Ignores unevaluated expressions", "[bundle]")
{
    // There is something like a require(opts.p || opts.default) in hbsfy. If this test passes, then the option was respected
    Paq* paq = new Paq(@[ @"fixtures/node_modules/hbsfy/index.js" ], @{ @"ignoreUnresolvableExpressions" : [NSNumber numberWithBool:YES] });
    NSError* err = nil;
    NSString* bundle = paq->bundleSync(nil, &err);
    REQUIRE(err == nil);
    REQUIRE([bundle lengthOfBytesUsingEncoding:NSUTF8StringEncoding] > 0);

    delete paq;
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

    delete paq;
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

    delete paq;
}

/*
TEST_CASE("Uses hbsfy transform", "[bundle]")
{
    // There is something like a require(opts.p || opts.default) in hbsfy. If this test passes, then the option was respected
    // because that kind of require can't be evaluated statically
    Paq* paq = new Paq(@[ @"fixtures/hbs-app/index.js" ], @{ @"ignoreUnresolvableExpressions" : [NSNumber numberWithBool:YES],
        @"transforms" : @[ @"hbsfy" ] });

    NSError* err = nil;
    NSString* bundle = paq->bundleSync(nil, &err);
    REQUIRE(err == nil);
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
