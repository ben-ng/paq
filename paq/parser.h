//
//  parser.h
//  paq
//
//  Created by Ben on 3/24/15.
//  Copyright (c) 2015 Ben Ng. All rights reserved.
//

#import <string>
#import <Foundation/Foundation.h>
#import <JavaScriptCore/JavaScriptCore.h>
#import "script.h"

/**
 * The parser functions simply return an AST for some given code
 */

class Parser {
public:
    static NSDictionary* parse(JSContext* ctx, NSString* code, NSError** err);
    static JSContext* createContext();
};
