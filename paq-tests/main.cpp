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

TEST_CASE( "Parser returns a valid AST", "[]" ) {
    Parser::parse(Parser::createContext(), @"require(__dirname + 'path')", ^(NSString *err, NSDictionary *ast) {
        REQUIRE(err == nil);
        REQUIRE(ast[@"type"] != nil);
        REQUIRE([ast[@"type"] isEqualToString:@"Program"]);
        REQUIRE([((NSArray *)ast[@"body"]) count] == 1);
        REQUIRE([((NSString *) ast[@"body"][0][@"type"]) isEqualToString: @"ExpressionStatement"]);
    });
}
