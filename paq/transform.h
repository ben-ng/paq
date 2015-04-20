//
//  transform.h
//  paq
//
//  Created by Ben on 3/24/15.
//  Copyright (c) 2015 Ben Ng. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <JavaScriptCore/JavaScriptCore.h>
#import "PseudoBrowserJSContext.h"
#import "json.h"

/**
 * The parser functions simply return an AST for some given code
 */

class Transform {
private:
    NSUInteger _max_tasks;
    NSMutableArray* _contexts;
    dispatch_queue_t _accessQueue;
    dispatch_semaphore_t _contextSema;
    NSString* _transformChain;
    PseudoBrowserJSContext* createContext();

public:
    Transform(NSDictionary* options);
    Transform();
    void transform(NSString* path, NSString* code, void (^callback)(NSError* error, NSString* source));
};
