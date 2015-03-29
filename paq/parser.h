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
    NSUInteger _roundRobinCounter;
    NSMutableArray* _virtualMachines;
    dispatch_queue_t _accessQueue;

public:
    Parser(NSDictionary* options);
    ~Parser();
    NSDictionary* parse(NSString* code, NSError** err);
};
