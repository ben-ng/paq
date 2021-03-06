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
private:
    NSUInteger _max_tasks;
    NSMutableArray* _contexts;
    dispatch_queue_t _accessQueue;
    dispatch_semaphore_t _contextSema;
    JSContext* createContext();

public:
    Parser(NSDictionary* options);
    ~Parser();
    void parse(NSString* code, void (^callback)(NSError* error, NSArray* literals, NSArray* expressions, NSString* source));
};
