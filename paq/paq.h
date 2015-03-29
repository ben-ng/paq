//
//  paq.h
//  paq
//
//  Created by Ben on 3/25/15.
//  Copyright (c) 2015 Ben Ng. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <dispatch/dispatch.h>
#import "JSContextExtensions.h"
#import "parser.h"
#import "require.h"
#import "resolve.h"
#import "pack.h"

class Paq {
private:
    unsigned long _unprocessed;
    dispatch_queue_t _serialQ;
    dispatch_queue_t _concurrentQ;
    Parser* _parser;
    Require* _require;
    Resolve* _resolve;
    NSMutableDictionary* _module_map;
    NSMutableArray* _available_require_contexts;
    NSArray* _entry;
    NSDictionary* _options;
    NSDictionary* _nativeModules;

    /*
     * This is a map like
     * {
     *      @"/absolute/path.js": @{
     *          @"deps":@[
     *              @[@"requiredExpression", @"/resolved/path.js"]
     *          ],
     *          @"source": @"var some = 'source code';",
     *          @"entry": 1;
     *      }
     *  }
     */
    void (^_deps_callback)(NSDictionary* deps);

    void deps(NSString* file, NSMutableDictionary* parent, BOOL isEntry);
    NSArray* _getAST(NSString* file, NSError** error);
    void _resolveRequires(NSArray* requires, NSMutableDictionary* parent, void (^callback)(NSArray* resolved));
    NSString* _insertGlobals(NSString* file, NSString* source);

public:
    Paq(NSArray* entry, NSDictionary* options);
    ~Paq();
    /*
     * The main interface between this class and the outside world
     * [options]
     *   [BOOL eval] - If true, the bundle will return the entry script's export
     */
    void bundle(NSDictionary* options, void (^callback)(NSError* error, NSString* bundle));
    NSString* bundleSync(NSDictionary* options, NSError** error);
    NSString* evalToString();
    void deps(void (^callback)(NSDictionary* dependencies));
};
