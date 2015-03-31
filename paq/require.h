//
//  require.h
//  paq
//
//  Created by Ben on 3/25/15.
//  Copyright (c) 2015 Ben Ng. All rights reserved.
//

#import <vector>
#import <string>
#import <Foundation/Foundation.h>
#import <JavaScriptCore/JavaScriptCore.h>
#import "script.h"
#import "json.h"

class Require {
private:
    NSUInteger _max_tasks;
    NSString* _pathSrc;
    NSMutableArray* _contexts;
    dispatch_queue_t _accessQueue;
    dispatch_semaphore_t _contextSema;
    BOOL _ignore_unresolvable;
    static BOOL isRequire(NSDictionary* node);
    JSContext* createContext();

public:
    Require(NSDictionary* options);
    ~Require();
    void evaluateRequireExpressions(NSString* path, NSArray* expressions, void (^callback)(NSError* error, NSArray* requires));
};
