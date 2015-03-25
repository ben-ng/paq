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


TEST_CASE( "Traverses an AST", "[parser, traverse]" ) {
    NSError *err;
    NSDictionary *ast = Parser::parse(Parser::createContext(), @"require(__dirname + 'path')", &err);
    __block unsigned int nodeCounter = 0;
    
    Traverse::walk(ast, ^(NSObject *node) {
        nodeCounter++;
    });
    
    REQUIRE(nodeCounter == 7);
}
