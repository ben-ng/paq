//
//  main.cpp
//  paq
//
//  Created by Ben on 3/23/15.
//  Copyright (c) 2015 Ben Ng. All rights reserved.
//

#import "parser.h"

int main(int argc, const char * argv[]) {
    NSDictionary *ast = Parser::parse(Parser::createContext(), @"require(__dirname + 'path')", nil);
    return 0;
}
