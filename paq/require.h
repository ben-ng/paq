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
#import "traverse.h"
#import "json.h"

class Require {
private:
    BOOL _ignore_unresolvable;
    NSUInteger _max_tasks;
    NSUInteger _roundRobinCounter;
    NSString* _pathSrc;
    NSMutableArray* _virtualMachines;
    dispatch_queue_t _accessQueue;
    static BOOL isRequire(NSDictionary* node);

public:
    Require(NSDictionary* options);
    ~Require();
    NSArray* findRequires(NSString* path, NSDictionary* ast, NSError** error);
};
